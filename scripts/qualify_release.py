#!/usr/bin/env python3
"""Qualify the assembled runtime v1 release against local synthetic PostgreSQL.

The server receives caller runtime configuration only. Isolation permission is
set solely in a separate release-eval observer; no release configuration is patched.
"""
import argparse
from contextlib import contextmanager
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
import time
import urllib.error
import urllib.parse
import urllib.request

sys.dont_write_bytecode = True
import qualify_callers as callers

ROOT = Path(__file__).resolve().parents[1]


def run(argv, cwd, env):
    capture = ["foundry", "capture", "--"] if shutil.which("foundry") else []
    process = None
    try:
        with callers.defer_interrupts():
            process = subprocess.Popen(capture + argv, cwd=cwd, env=env,
                                       start_new_session=True)
        if process.wait():
            raise RuntimeError(f"Boundary command failed: {argv[0]}")
    finally:
        if process is not None:
            callers.stop(process)


def sql(database, query, admin):
    return callers.output(["psql", "-X", "-v", "ON_ERROR_STOP=1", "-At",
                           "-d", database, "-c", query], env=admin, text=True).strip()


def health(port):
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/health/ready", timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


@contextmanager
def server(release, env, port):
    # Default release node names also collide on this shared host. Serialize
    # every server probe without changing the caller's runtime environment.
    with open("/tmp/bedrock-port-4000.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with runtime_server(release, env, port):
            yield


@contextmanager
def runtime_server(release, env, port):
    # Port availability and whole-group shutdown occur under the shared lock.
    with socket.socket() as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        probe.bind(("127.0.0.1", port))
    log = callers.LOGS / f"release-{secrets.token_hex(8)}.log"
    callers.LOGS.mkdir(parents=True, exist_ok=True)
    process = None
    with log.open("w") as output:
        try:
            with callers.defer_interrupts():
                process = subprocess.Popen([str(release / "bin/server")], env=dict(env, PORT=str(port)),
                                           stdout=output, stderr=output, start_new_session=True)
            for _ in range(60):
                if process.poll() is not None:
                    raise RuntimeError(f"Release exited; inspect {log}")
                try:
                    if health(port) == (200, {"status": "ready", "runtime_version": 1}):
                        break
                except OSError:
                    time.sleep(0.25)
            else:
                raise RuntimeError(f"Release readiness timeout; inspect {log}")
            print(f"Foreground release ready on PORT={port}; server log {log}", flush=True)
            yield
        finally:
            if process is not None:
                callers.stop(process)
            with socket.socket() as probe:
                probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                probe.bind(("127.0.0.1", port))
            print(f"All owned listeners stopped on PORT={port}", flush=True)


def observer(release, source, env, expression):
    # This permission never enters the server environment. The observer uses
    # the same synthetic database URL and the shipped release code and config.
    database = urllib.parse.urlparse(env["DATABASE_URL"])
    assert database.hostname in {"127.0.0.1", "localhost"}
    assert database.path.startswith("/release_qualification_")
    assert env["MAIL_ADAPTER"] == "disabled" and env["LEAD_NOTIFICATIONS"] == "false"
    prefix = '''
    Application.put_env(:business, :exploration, true)
    endpoint = Application.fetch_env!(:business, BusinessWeb.Endpoint)
    Application.put_env(:business, BusinessWeb.Endpoint, Keyword.put(endpoint, :server, false))
    '''
    run([str(release / "bin/business"), "eval", prefix + expression], source, env)


def qualify(args):
    admin = {key: value for key, value in os.environ.items()
             if key in {"PATH", "HOME", "LANG", "PGHOST", "PGPORT", "PGUSER", "PGPASSWORD"}}
    admin.setdefault("PGHOST", "127.0.0.1")
    admin.setdefault("PGUSER", "postgres")
    admin.setdefault("PGPASSWORD", "postgres")
    assert admin["PGHOST"] in {"127.0.0.1", "localhost"}, "Use local synthetic PostgreSQL only"
    build = {key: value for key, value in os.environ.items()
             if key in {"PATH", "HOME", "LANG", "MIX_HOME", "HEX_HOME"}}
    build.update(MIX_ENV="prod", ERL_FLAGS="+S 4:4")
    pinned = dict(line.split() for line in (ROOT / ".tool-versions").read_text().splitlines())
    versions = callers.output(["elixir", "-e", 'IO.puts(System.version() <> "-otp-" <> System.otp_release()); IO.puts(File.read!(Path.join([to_string(:code.root_dir()), "releases", System.otp_release(), "OTP_VERSION"])) |> String.trim())'], env=build, text=True).splitlines()
    assert versions == [pinned["elixir"], pinned["erlang"]], versions
    print(f"Pinned toolchain: {versions}; local PostgreSQL: {sql('postgres', 'SHOW server_version', admin)}", flush=True)
    print("Committed starter baseline:", callers.output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), flush=True)
    database = "release_qualification_" + secrets.token_hex(10)
    with callers.disposable_snapshot(args.snapshot_parent) as scratch:
        source = scratch / "source"
        source.mkdir()
        callers.snapshot(source)
        if args.release:
            artifact = args.release.resolve()
        else:
            # Reuse dependencies only as a build cache; all authored bytes come
            # from the exact baseline plus the identified candidate changes.
            if (ROOT / "deps").is_dir():
                shutil.copytree(ROOT / "deps", source / "deps")
            if (ROOT / "_build").is_dir():
                shutil.copytree(ROOT / "_build", source / "_build", symlinks=True)
            locked = (source / "mix.lock").read_bytes()
            for command in [["mix", "deps.get"], ["mix", "assets.deploy"], ["mix", "release", "--overwrite"]]:
                run(command, source, build)
                assert (source / "mix.lock").read_bytes() == locked, "Build changed the candidate lockfile"
            artifact = source / "_build/prod/rel/business"
        release = scratch / "release"
        shutil.copytree(artifact, release, symlinks=True)
        digest = hashlib.sha256()
        for file in sorted(release.rglob("*")):
            if file.is_file():
                digest.update(str(file.relative_to(release)).encode() + b"\0" + file.read_bytes())
        print("Release artifact SHA-256:", digest.hexdigest(), flush=True)
        user = urllib.parse.quote(admin["PGUSER"], safe="")
        password = urllib.parse.quote(admin["PGPASSWORD"], safe="")
        env = {key: build[key] for key in ("PATH", "HOME", "LANG") if key in build}
        env.update(DATABASE_URL=f"ecto://{user}:{password}@{admin['PGHOST']}:{admin.get('PGPORT', '5432')}/{database}",
                   DATABASE_SSL="false", SECRET_KEY_BASE=secrets.token_hex(64),
                   PHX_HOST="localhost", PHX_SCHEME="http", PORT="4000", POOL_SIZE="2",
                   ERL_FLAGS="+S 2:2", AWS_REGION="ca-central-1",
                   MAIL_ADAPTER="disabled", LEAD_NOTIFICATIONS="false")
        print("Server environment keys:", sorted(env), flush=True)
        try:
            run(["createdb", database], source, admin)
            tables = "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename"
            assert sql(database, tables, admin) == ""
            with socket.socket() as probe:
                probe.bind(("127.0.0.1", 0))
                port = probe.getsockname()[1]
            with server(release, env, port):
                assert sql(database, tables, admin) == "", "ordinary startup migrated"
                print("Ordinary startup left the empty database unchanged; PORT honoured", flush=True)
                sql("postgres", f'ALTER DATABASE "{database}" ALLOW_CONNECTIONS false', admin)
                sql("postgres", f"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='{database}'", admin)
                assert health(port) == (503, {"status": "unavailable"}), "database failure reported ready"
                print("Real database access revoked: HTTP 503 unavailable", flush=True)
            sql("postgres", f'ALTER DATABASE "{database}" ALLOW_CONNECTIONS true', admin)
            run([str(release / "bin/migrate")], source, env)
            assert sql(database, tables, admin).splitlines() == ["leads", "schema_migrations", "users", "users_tokens"]
            print("bin/migrate created leads, users, users_tokens and schema_migrations", flush=True)
            if args.proof:
                print("Smallest release readiness/migration proof passed (full smoke still required)", flush=True)
                return
            expected = scratch / "retained.json"
            seed_env = dict(env, SMOKE_EXPECTATION_PATH=str(expected))
            observer(release, source, seed_env,
                     '{:ok, _} = Application.ensure_all_started(:business); Code.eval_file("scripts/qualification_seed.exs")')
            smoke_env = dict(env, SMOKE_EXISTING_LEAD=expected.read_text())
            with server(release, env, 4000):
                observer(release, source, smoke_env, 'Code.eval_file("scripts/smoke.exs")')
                sql("postgres", f'ALTER DATABASE "{database}" ALLOW_CONNECTIONS false', admin)
                sql("postgres", f"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='{database}'", admin)
                status, body = health(4000)
                assert (status, body) == (503, {"status": "unavailable"}), "database failure reported ready"
                print("Real database access revoked: HTTP 503 unavailable", flush=True)
        finally:
            with callers.defer_interrupts():
                run(["dropdb", "--if-exists", "--force", database], source, admin)
                print(f"Removed synthetic database {database}", flush=True)
    print("Runtime v1 release acceptance passed", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=Path, help="Probe an already assembled artifact (regression experiments)")
    parser.add_argument("--proof", action="store_true", help="Smallest real readiness/migration probe; CI always runs the full gate")
    parser.add_argument("--snapshot-parent", type=Path, default=Path("/tmp"),
                        help="Existing private parent for cleanup observers")
    for number in (signal.SIGINT, signal.SIGTERM):
        signal.signal(number, callers.interrupted)
    qualify(parser.parse_args())
