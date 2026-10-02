#!/usr/bin/env python3
"""Independently observe the production finalizer under its first interrupt.

The AST executes the qualifier's exact final cleanup block, nested inside its
real snapshot and lock contexts. Resources are real disposable PostgreSQL,
listener process groups and directories. A transparent dropdb launcher pauses
before exec solely to make the database-cleanup signal window deterministic.
No cleanup call or outcome is mocked. Observer recovery is reported separately.
"""
import argparse
import ast
import fcntl
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import qualify_callers as callers
import qualify_workshop as workshop

LOCK = Path('/tmp/bedrock-port-4000.lock')


def emit(event, **values):
    print(json.dumps(dict(event=event, **values)), flush=True)


def locked():
    with LOCK.open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        return False


def listening():
    with socket.socket() as probe:
        probe.settimeout(.1)
        return probe.connect_ex(('127.0.0.1', 4000)) == 0


def exists(database):
    return bool(subprocess.check_output(['psql', '-d', 'postgres', '-Atc',
        f"select datname from pg_database where datname='{database}'"], text=True).strip())


def wait_for(predicate, timeout=40):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.01)
    raise AssertionError('Timed out waiting for real resource boundary')


def worker(source, directory, database, stage):
    for number in (signal.SIGTERM, signal.SIGINT):
        signal.signal(number, callers.interrupted)
    report = {'cleanup': {}}
    report_path = directory / 'report.json'
    with workshop.monitored_snapshot(report, report_path) as temporary:
        (directory / 'snapshot').write_text(str(temporary))
        context = temporary / 'context'
        context.mkdir()
        app = temporary
        env = dict(os.environ)
        if stage == 'database':
            launcher = temporary / 'dropdb'
            launcher.write_text('#!' + sys.executable + '\nimport os,signal\n'
                + 'from pathlib import Path\n'
                + 'marker=Path(' + repr(str(directory / 'drop.pid')) + ')\n'
                + 'if not marker.exists():\n marker.write_text(str(os.getpid()))\n os.kill(os.getpid(),signal.SIGSTOP)\n'
                + 'os.execv(' + repr(shutil.which('dropdb')) + ',["dropdb"]+__import__("sys").argv[1:])\n')
            launcher.chmod(0o700)
            env['PATH'] = str(temporary) + ':' + env['PATH']
        databases = [database, database + '_retained']
        with LOCK.open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            for name in databases:
                subprocess.run(['createdb', name], check=True)
            listener_code = ('import socket,signal,time\nfrom pathlib import Path\n'
                's=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)\n'
                's.bind(("127.0.0.1",4000)); s.listen()\n'
                'signal.signal(signal.SIGTERM, lambda *_: Path(' + repr(str(directory / 'shutdown.entered')) + ').touch())\n'
                'print("ready",flush=True)\ntime.sleep(120)\n')
            listener = subprocess.Popen([sys.executable, '-u', '-c', listener_code],
                stdout=subprocess.PIPE, text=True, start_new_session=True)
            assert listener.stdout.readline().strip() == 'ready'
            (context / 'server.pid').write_text(str(listener.pid))
            (directory / 'listener.pid').write_text(str(listener.pid))
            (directory / 'ready').touch()
            wait_for(lambda: (directory / 'go').exists())
            tree = ast.parse(source.read_text())
            qualify = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'qualify')
            finalizer = next(node.finalbody for node in ast.walk(qualify)
                             if isinstance(node, ast.Try) and node.finalbody)
            # The surrounding try forces normal entry into final cleanup.
            code = ast.Module(body=[ast.Try(body=[ast.Pass()], handlers=[], orelse=[], finalbody=finalizer)], type_ignores=[])
            scope = dict(workshop.__dict__, **locals())
            exec(compile(ast.fix_missing_locations(code), str(source), 'exec'), scope)


def observe(source, stage, number):
    directory = Path(tempfile.mkdtemp(prefix='workshop-cleanup-observer-'))
    database = 'workshop_cleanup_' + secrets.token_hex(10)
    command = [sys.executable, '-B', str(Path(__file__).resolve()), '--worker',
               '--source', str(source), '--directory', str(directory), '--database', database, '--stage', stage]
    child = subprocess.Popen(command)
    pid, snapshot = None, None
    violations = []
    try:
        wait_for(lambda: (directory / 'ready').exists() or child.poll() is not None, timeout=1200)
        assert child.poll() is None, 'Worker exited before allocating its listener'
        pid = int((directory / 'listener.pid').read_text())
        snapshot = Path((directory / 'snapshot').read_text())
        assert exists(database) and snapshot.exists() and listening() and locked()
        (directory / 'go').touch()
        if stage == 'shutdown':
            # stop_pid is waiting for this real SIGTERM-resistant listener.
            wait_for(lambda: (directory / 'shutdown.entered').exists())
        else:
            wait_for(lambda: (directory / 'drop.pid').exists())
        child.send_signal(number)
        if stage == 'database':
            time.sleep(.1)
            os.kill(int((directory / 'drop.pid').read_text()), signal.SIGCONT)
        while child.poll() is None:
            if listening() and not locked():
                violations.append('lock released while listener survives')
            time.sleep(.01)
        live, sql, files = callers.group_running(pid), [name for name in [database, database + '_retained'] if exists(name)], snapshot.exists()
        if listening() and not locked():
            violations.append('lock released while listener survives')
        emit('observation', stage=stage, signal=number, worker_exit=child.returncode,
             listener_survives=live, database_survives=sql, snapshot_survives=files,
             lock_order_violations=violations, source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
        assert child.returncode == 128 + number
        assert not (live or sql or files or violations), 'Final cleanup skipped owned resources'
    finally:
        if snapshot is None and (directory / 'snapshot').exists():
            snapshot = Path((directory / 'snapshot').read_text())
        if child.poll() is None:
            child.kill()
            child.wait()
        if pid and callers.group_running(pid):
            # Recover the rejecting implementation under the canonical lock.
            with LOCK.open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                workshop.stop_pid(pid)
        for name in [database, database + '_retained']:
            subprocess.run(['dropdb', '--if-exists', '--force', name], check=True)
        if snapshot and snapshot.exists():
            shutil.rmtree(snapshot)
        shutil.rmtree(directory)
        emit('observer_recovery', database_absent=not any(exists(name) for name in [database, database + '_retained']), snapshot_absent=not snapshot or not snapshot.exists(),
             owned_process_absent=not pid or not callers.group_running(pid))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).with_name('qualify_workshop.py'))
    parser.add_argument('--stage', choices=['shutdown', 'database'], required=True)
    parser.add_argument('--signal', choices=['SIGTERM', 'SIGINT'], default='SIGTERM')
    parser.add_argument('--worker', action='store_true')
    parser.add_argument('--directory', type=Path)
    parser.add_argument('--database')
    args = parser.parse_args()
    if args.worker:
        worker(args.source, args.directory, args.database, args.stage)
    else:
        observe(args.source, args.stage, getattr(signal, args.signal))
