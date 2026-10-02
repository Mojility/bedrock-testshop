#!/usr/bin/env python3
"""Observe the real qualifier's listener, children, shared lock and disposable SQL.

Run each case through `foundry capture --`. Only the qualifier's uniquely named
synthetic snapshot/database/processes are inspected or removed. Signal cases
pause the real BEAM listener to exercise shutdown escalation and lock ordering.
Success runs full preparation and both publication states; other cases use the
smaller production probe. No build or smoke command is replaced.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
LOCK = Path('/tmp/bedrock-port-4000.lock')


def emit(event, **values):
    print(json.dumps({'event': event, **values}), flush=True)


def lock_owned():
    with LOCK.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        fcntl.flock(lock, fcntl.LOCK_UN)
        return False


def listener_present():
    with socket.socket() as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            probe.bind(('127.0.0.1', 4000))
            return False
        except OSError:
            return True


def processes(snapshot=None, groups=None):
    members = []
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            fields = (proc / 'stat').read_text().rsplit(') ', 1)[1].split()
            group = int(fields[2])
            if fields[0] == 'Z':
                continue
            command = (proc / 'cmdline').read_bytes()
            cwd = os.readlink(proc / 'cwd')
            if ((snapshot and (str(snapshot) in cwd or str(snapshot).encode() in command))
                    or (groups and group in groups)):
                members.append((int(proc.name), group, b'beam.smp' in command))
        except (FileNotFoundError, ProcessLookupError):
            continue
    return members


def database_present(database):
    result = subprocess.check_output([
        'psql', '-d', 'postgres', '-Atc',
        f"select datname from pg_database where datname = '{database}'"
    ], text=True)
    return bool(result.strip())


def verify(args):
    parent = Path(tempfile.mkdtemp(prefix='caller-observer-', dir='/tmp'))
    qualifier = ROOT / 'scripts/qualify_callers.py'
    command = [sys.executable, '-B', '-u', str(qualifier), '--bedrock', str(args.bedrock),
               '--snapshot-parent', str(parent)]
    if args.bedrock_revision:
        command += ['--bedrock-revision', args.bedrock_revision]
    if args.case != 'success':
        command.append('--proof')
    emit('source', command=command, qualifier_sha256=hashlib.sha256(qualifier.read_bytes()).hexdigest())
    child = subprocess.Popen(command, start_new_session=True)
    snapshots, groups, database = [], set(), None
    try:
        deadline = time.monotonic() + 1200
        while child.poll() is None and time.monotonic() < deadline:
            snapshots = list(parent.glob('qualification-*'))
            if len(snapshots) == 1:
                config = snapshots[0] / 'runtime/app/config/runtime.exs'
                if config.exists():
                    match = re.search(r'database: "(qualification_[a-f0-9]+)"', config.read_text())
                    database = match[1] if match else None
            if database and listener_present() and lock_owned():
                try:
                    with urllib.request.urlopen('http://127.0.0.1:4000/health/ready', timeout=.2) as response:
                        if response.status == 200:
                            break
                except OSError:
                    pass
            time.sleep(.02)
        else:
            raise AssertionError('Qualifier never reached its real, locked HTTP listener')

        members = processes(snapshot=snapshots[0])
        groups.update(group for _, group, _ in members)
        emit('listener_ready', database=database, snapshot=str(snapshots[0]),
             shared_lock_owned=lock_owned(), processes=members)
        if args.case in ('sigterm', 'sigint'):
            for pid, _, beam in members:
                if beam:
                    os.kill(pid, signal.SIGSTOP)
            child.send_signal(signal.SIGTERM if args.case == 'sigterm' else signal.SIGINT)
        elif args.case == 'failure':
            # Lose real delivered CSS in the disposable runtime, so the actual
            # smoke command fails at HTTP rather than receiving a fake receipt.
            styles = list((snapshots[0] / 'runtime/app/priv/static/assets/css').glob('*.css'))
            assert styles, 'No deployed CSS to remove'
            for path in styles:
                path.write_text('')
                for suffix in ('.gz', '.br'):
                    Path(str(path) + suffix).unlink(missing_ok=True)
            emit('lost_stylesheet_delivery', files=[str(path) for path in styles])

        observations, violations = 0, []
        deadline = time.monotonic() + 600
        while child.poll() is None and time.monotonic() < deadline:
            if listener_present():
                observations += 1
                if not lock_owned():
                    # Sample again to exclude termination between the two reads.
                    if listener_present():
                        violations.append('Listener remained after lock release')
            groups.update(group for _, group, _ in processes(snapshot=snapshots[0]))
            time.sleep(.02)
        code = child.wait(timeout=5)
        expected = {'success': 0, 'sigterm': 143, 'sigint': 130}.get(args.case)
        assert (code == expected if expected is not None else code != 0), f'Unexpected exit {code}'
        result = dict(exit_code=code, listener=listener_present(), database_exists=database_present(database),
                      snapshots=[str(path) for path in snapshots if path.exists()],
                      live_children=processes(groups=groups), lock_observations=observations,
                      lock_violations=violations, lock_released=not lock_owned())
        emit('cleanup', **result)
        assert observations > 0 and not violations, 'Shared lock ordering failed'
        assert not result['listener'] and not result['database_exists'], 'Listener/database remained'
        assert not result['snapshots'] and not result['live_children'], 'Snapshot/children remained'
        assert result['lock_released'], 'Shared lock was not released after termination'
    finally:
        # Rescue only this run's owned resources if the acceptance assertion
        # fails. Reported results above always precede this independent cleanup.
        if child.poll() is None:
            child.kill()
            child.wait()
        groups.update(group for path in snapshots for _, group, _ in processes(snapshot=path))
        for group in groups | {child.pid}:
            try:
                os.killpg(group, signal.SIGKILL)
            except ProcessLookupError:
                pass
        if database and database_present(database):
            subprocess.run(['dropdb', '--if-exists', '--force', database], check=True)
        for path in snapshots:
            if path.exists():
                shutil.rmtree(path)
        parent.rmdir()
    emit('verified', case=args.case, snapshot_parent_removed=not parent.exists())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bedrock', type=Path, required=True)
    parser.add_argument('--bedrock-revision', help='Identity of a permitted trunk archive')
    parser.add_argument('--case', choices=['sigterm', 'sigint', 'failure', 'success'], required=True)
    verify(parser.parse_args())
