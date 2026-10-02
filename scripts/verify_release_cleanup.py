#!/usr/bin/env python3
"""Observe signal cleanup of a real, paused port-4000 release listener.

Only this observer's private snapshot, process groups and synthetic database are
inspected. The real runner must retain the shared lock until its listener stops.
"""
import argparse
import fcntl
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
import qualify_callers as callers

ROOT = Path(__file__).resolve().parents[1]


def owned_listener(parent):
    for entry in Path("/proc").glob("[0-9]*"):
        try:
            command = (entry / "cmdline").read_bytes()
            if b"beam.smp" not in command or str(parent).encode() not in command:
                continue
            values = dict(part.split(b"=", 1) for part in
                          (entry / "environ").read_bytes().split(b"\0") if b"=" in part)
            if values.get(b"PORT") != b"4000":
                continue
            database = values[b"DATABASE_URL"].decode().rsplit("/", 1)[1]
            group = int((entry / "stat").read_text().rsplit(") ", 1)[1].split()[2])
            assert database.startswith("release_qualification_")
            return int(entry.name), group, database
        except (FileNotFoundError, ProcessLookupError):
            continue
    raise AssertionError("No owned release listener found")


def listener_present():
    with socket.socket() as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            probe.bind(("127.0.0.1", 4000))
            return False
        except OSError:
            return True


def observe_shutdown(child, group):
    deadline = time.monotonic() + 60
    with open("/tmp/bedrock-port-4000.lock", "a") as lock:
        while child.poll() is None:
            assert time.monotonic() < deadline, "Signal cleanup exceeded its deadline"
            if callers.group_running(group) and listener_present():
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    pass
                else:
                    # Exclude shutdown between the process/port and lock samples.
                    try:
                        assert not (callers.group_running(group) and listener_present()), \
                            "Lock released while owned listener remained"
                    finally:
                        fcntl.flock(lock, fcntl.LOCK_UN)
            time.sleep(0.02)


def verify(args):
    signal_number = getattr(signal, args.signal)
    with tempfile.TemporaryDirectory(prefix="release-signal-observer-") as directory:
        parent = Path(directory)
        command = [sys.executable, "-B", "-u", str(ROOT / "scripts/qualify_release.py"),
                   "--release", str(args.release.resolve()), "--snapshot-parent", str(parent)]
        child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, start_new_session=True)
        database, group = None, None
        try:
            while line := child.stdout.readline():
                print(line, end="", flush=True)
                if "Foreground release ready on PORT=4000;" in line:
                    listener, group, database = owned_listener(parent)
                    # Force slow shutdown to exercise escalation and lock lifetime.
                    os.kill(listener, signal.SIGSTOP)
                    child.send_signal(signal_number)
                    observe_shutdown(child, group)
                    break
            for line in child.stdout:
                print(line, end="", flush=True)
            code = child.wait()
            assert code == 128 + signal_number, (code, signal_number)
            assert database is not None, "Never reached the owned release listener"
            assert not list(parent.iterdir()), "Snapshot remained"
            found = subprocess.check_output([
                "psql", "-X", "-d", "postgres", "-Atc",
                f"SELECT datname FROM pg_database WHERE datname='{database}'"
            ], text=True).strip()
            assert not found, "Synthetic database remained"
            assert not callers.group_running(group), "Listener process group remained"
            print(f"{args.signal}: expected exit {code}; listener stopped before lock release; "
                  "database and snapshot removed", flush=True)
        finally:
            callers.stop(child)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--signal", choices=["SIGTERM", "SIGINT"], required=True)
    parser.add_argument("--release", type=Path, required=True)
    verify(parser.parse_args())
