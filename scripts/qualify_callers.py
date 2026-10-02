#!/usr/bin/env python3
"""Execute Bedrock trunk's preparation commands against disposable starter source.

Only this repository and the explicitly supplied Bedrock source are read. No
customer, provider or production endpoints are used. Source and databases are
discarded on success, failure, SIGINT and SIGTERM. Capture logs stay outside
the source tree in Foundry's default external log directory.
"""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
import re
from pathlib import Path
import secrets
import shlex
import shutil
import signal
import socket
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
LOGS = Path.home() / ".foundry/tool-logs"


def list_checks(proof=False):
    """Describe the execution path without acquiring source or running checks."""
    checks = [
        ("caller-source", "Verify clean current Bedrock trunk or committed archive identity; compile actual Bootstrap/Preparation to obtain stage, compile, service and smoke commands."),
        ("toolchain", "Require the exact pinned Elixir/OTP versions."),
        ("cold-preparation", "Execute cold dependency preparation and assets deployment in a disposable exact-source candidate."),
        ("production-compile", "Execute Bedrock's MIX_ENV=prod compilation and promotion command."),
        ("synthetic-database", "Create a unique synthetic database and run migrations; disable mail and provider credentials."),
        ("baseline", "Serve the unpublished page on port 4000; check readiness, public page and usable enquiry form."),
        ("deployed-css", "Fetch nonempty local CSS with text/css responses from public and staff pages, including deployed digested URLs."),
        ("csrf", "Refuse a tokenless enquiry with HTTP 403 and verify no database write."),
        ("anonymous-staff", "Redirect anonymous staff access to sign-in."),
        ("enquiry-persistence", "Submit with CSRF and verify stored name, phone, email and request message."),
        ("magic-link-session", "Submit a synthetic magic-link token and verify the session permits authenticated staff HTTP reads."),
        ("authenticated-reads", "Read the new and retained enquiries through staff HTTP, including contact, request, follow-up notes and timestamp."),
        ("retained-integrity", "Compare retained database fields exactly: identity, contact, request, source, status, notes, legacy ID, inserted_at and seen_at."),
        ("cleanup", "Remove smoke-owned records, stop every listener process before releasing the shared port lock, drop the synthetic database and remove snapshots on success, failure, SIGINT and SIGTERM."),
    ]
    if not proof:
        checks[3:3] = [
            ("preparation-environments", "Cold preparation builds dev/test/prod dependencies and compiles application source; assets deploy in prod using current Bedrock commands."),
            ("cached-preparation", "Run retained preparation/cache promotion against a second snapshot with identical candidate source identity."),
        ]
        checks[7:7] = [
            ("retained-before-startup", "Seed a synthetic retained enquiry before startup and check the same record across both publication states."),
            ("published", "Repeat HTTP/database smoke on the compatible synthetic published scene with deployed assets; preserve fixture compatibility hash and publication provenance."),
        ]
    print("Discovery only: inventory is not passing behavioral evidence.")
    print("Path: " + ("--proof (prod-only, baseline only; no cached preparation or pre-start retained seed)"
                      if proof else "full qualification (cold/cached preparation; baseline and published smoke)"))
    for name, description in checks:
        print(f"{name}: {description}")


def interrupted(signum, _frame):
    # The first signal starts unwinding. Further signals must not interrupt
    # child shutdown, database removal or snapshot removal.
    for number in (signal.SIGINT, signal.SIGTERM):
        signal.signal(number, signal.SIG_IGN)
    raise SystemExit(128 + signum)


@contextmanager
def defer_interrupts():
    previous = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM})
    try:
        yield
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous)


@contextmanager
def disposable_snapshot(parent):
    temporary = None
    try:
        with defer_interrupts():
            temporary = tempfile.mkdtemp(prefix="qualification-", dir=parent)
        yield Path(temporary)
    finally:
        if temporary is not None:
            with defer_interrupts():
                shutil.rmtree(temporary)
            print(f"Removed snapshot {temporary}", flush=True)


def group_running(group):
    # killpg(0) also finds zombies. They no longer own listeners; their parent
    # reaps them. Inspect live members, including children of an exited shell.
    for path in Path("/proc").glob("[0-9]*/stat"):
        try:
            fields = path.read_text().rsplit(") ", 1)[1].split()
            if int(fields[2]) == group and fields[0] != "Z":
                return True
        except (FileNotFoundError, ProcessLookupError):
            continue
    return False


def stop(process):
    with defer_interrupts():
        stop_group(process)


def stop_group(process):
    # Waiting for the launcher alone can release the shared lock while its
    # BEAM child still listens. Terminate and wait for the entire process group.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    deadline = time.monotonic() + 10
    while group_running(process.pid) and time.monotonic() < deadline:
        process.poll()
        time.sleep(0.05)
    if group_running(process.pid):
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    # Do not unwind the lock context until even a slow listener is gone.
    while group_running(process.pid):
        process.poll()
        time.sleep(0.05)
    process.wait()


def run(command, cwd, env):
    print("Executing:", " ".join(command), flush=True)
    process = None
    try:
        with defer_interrupts():
            process = subprocess.Popen(["foundry", "capture", "--", *command],
                                       cwd=cwd, env=env, start_new_session=True)
        code = process.wait()
        if code:
            raise subprocess.CalledProcessError(code, command)
    finally:
        if process is not None:
            stop(process)


def output(command, cwd=None, env=None, text=False, input=None):
    process = None
    try:
        with defer_interrupts():
            process = subprocess.Popen(command, cwd=cwd, env=env, text=text,
                                       stdin=subprocess.PIPE if input is not None else None,
                                       stdout=subprocess.PIPE, start_new_session=True)
        result, _ = process.communicate(input)
        if process.returncode:
            raise subprocess.CalledProcessError(process.returncode, command)
        return result
    finally:
        if process is not None:
            stop(process)


def snapshot(destination):
    # Archive the exact baseline, then apply this worktree's source changes.
    archive = output(["git", "archive", "HEAD"], cwd=ROOT)
    output(["tar", "-x", "-C", str(destination)], input=archive)
    identity = hashlib.sha256()
    for name in sorted(output(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=ROOT, text=True).splitlines()):
        if name.startswith(".foundry/"):
            continue
        source = ROOT / name
        target = destination / name
        if source.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            identity.update(name.encode() + b"\0" + source.read_bytes() + b"\0")
        elif target.exists():
            target.unlink()
    print("Candidate source SHA-256:", identity.hexdigest(), flush=True)
    return identity.hexdigest()


def commands(bedrock, stage, env, retained=False):
    directory = bedrock / "apps/bedrock/lib/bedrock/explorations"
    expression = f'''
    Code.compile_file({json.dumps(str(directory / "preparation.ex"))})
    Code.compile_file({json.dumps(str(directory / "bootstrap.ex"))})
    Application.put_env(:bedrock, :tenant_host_suffix, "mybedrock.ca")
    e = %{{repository_url: "https://github.com/Mojility/bedrock-system-template",
          source_commit: "{output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()}",
          tenant_id: "synthetic-qualification", parent_origin: "https://qualification.mybedrock.ca",
          media_origin: "https://qualification-media.mybedrock.ca",
          retained_storage: %{{{('"preparation_id" => "11111111-1111-4111-8111-111111111111"' if retained else '')}}}}}
    for phase <- ["stage", "compile", "service", "smoke"] do
      {{:ok, command}} = Bedrock.Explorations.Bootstrap.command(phase, e)
      IO.puts(phase <> ":" <> Base.encode64(command))
    end
    '''
    import base64
    result = output(
        ["elixir", "-pa", str(stage / "_build/prod/lib/ecto/ebin"), "-e", expression],
        cwd=stage, env=env, text=True)
    return {phase: base64.b64decode(value).decode()
            for phase, value in (line.split(":", 1) for line in result.splitlines())}


def qualify(args):
    LOGS.mkdir(parents=True, exist_ok=True)
    bedrock = args.bedrock.resolve()
    if args.bedrock_revision and not re.fullmatch("[a-f0-9]{40}", args.bedrock_revision):
        raise ValueError("Archive identity must be a full committed revision")
    if (bedrock / "apps/bedrock/lib/bedrock/explorations/bootstrap.ex").is_file() is False:
        raise ValueError("Supply the Bedrock trunk source, never a customer repository")
    print("Starter:", output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip())
    print("Bedrock:", args.bedrock_revision or output(["git", "rev-parse", "HEAD"], cwd=bedrock, text=True).strip())
    if not args.bedrock_revision and output(["git", "status", "--porcelain"], cwd=bedrock, text=True):
        raise ValueError("Bedrock command source must be clean")
    if not args.bedrock_revision and output(["git", "rev-parse", "HEAD"], cwd=bedrock) != output(
            ["git", "rev-parse", "refs/remotes/origin/main"], cwd=bedrock):
        raise ValueError("Bedrock source must match its current trunk reference")
    for name in ["bootstrap.ex", "preparation.ex"]:
        source = bedrock / "apps/bedrock/lib/bedrock/explorations" / name
        print(name, hashlib.sha256(source.read_bytes()).hexdigest())
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("AWS_", "EXPLORATION_", "DATABASE_", "PG", "MIX_", "HEX_", "SMOKE_"))}
    env.update(MIX_ENV="prod", ERL_FLAGS="+S 4:4", CUSTOMER_EXPLORATION="true",
               EXPLORATION_HOST="workspace.example.ca",
               EXPLORATION_PARENT_ORIGIN="https://qualification.mybedrock.ca",
               SECRET_KEY_BASE=secrets.token_hex(64), MAIL_ADAPTER="disabled",
               LEAD_NOTIFICATIONS="false")
    pinned = dict(line.split() for line in (ROOT / ".tool-versions").read_text().splitlines())
    versions = output(["elixir", "-e", 'IO.puts(System.version() <> "-otp-" <> System.otp_release()); IO.puts(File.read!(Path.join([to_string(:code.root_dir()), "releases", System.otp_release(), "OTP_VERSION"])) |> String.trim())'], env=env, text=True).splitlines()
    if versions != [pinned["elixir"], pinned["erlang"]]:
        raise ValueError(f"Use the pinned toolchain; observed {versions}")
    print("Toolchain:", versions, flush=True)
    with disposable_snapshot(args.snapshot_parent) as root:
        stage = root / "stage"
        stage.mkdir()
        source_identity = snapshot(stage)
        contract = commands(bedrock, stage, env)
        # Git acquisition is represented by the exact-source archive above. Execute
        # every build command from trunk, without touching refs or remote systems.
        build = contract["stage"].split("mix local.hex --force", 1)[1]
        build = "mix local.hex --force" + build
        (root / "source.lock").write_bytes((stage / "mix.lock").read_bytes())
        build = build.replace("git diff --exit-code -- mix.lock", f"cmp mix.lock {root / 'source.lock'}")
        env.update(MIX_HOME=str(stage / ".bedrock-tools/mix"), HEX_HOME=str(stage / ".bedrock-tools/hex"))
        if args.proof:
            build = "\n".join(line for line in build.splitlines()
                              if not line.startswith(("MIX_ENV=dev ", "MIX_ENV=test ")))
        run(["sh", "-eu", "-c", build], stage, env)
        if not args.proof:
            contract = commands(bedrock, stage, env, retained=True)
            cached = root / "cached-stage"
            cached.mkdir()
            if snapshot(cached) != source_identity:
                raise ValueError("Candidate source changed during qualification; rerun from stable source")
            cache = root / "preparation/cache"
            cache.mkdir(parents=True)
            helper = contract["stage"].split("# Stable dependency preparation", 1)[1]
            helper = "# Stable dependency preparation" + helper
            helper = helper.replace("/preparation/cache", str(cache)).replace("/staging/app", str(cached))
            helper = helper.replace("git diff --exit-code -- mix.lock", f"cmp mix.lock {root / 'source.lock'}")
            git_dir = output(["git", "rev-parse", "--absolute-git-dir"], cwd=ROOT, text=True).strip()
            helper = helper.replace("git ls-files -z", f"git --git-dir={shlex.quote(git_dir)} --work-tree={shlex.quote(str(cached))} ls-files -z")
            run(["sh", "-eu", "-c", helper], cached, env)
            shutil.copytree(stage / ".bedrock-tools/mix", cached / ".bedrock-tools/mix", dirs_exist_ok=True)
            stage = cached
        runtime = root / "runtime"
        runtime.mkdir()
        app = runtime / "app"
        shutil.copytree(stage, app, symlinks=True)
        contract = {key: value.replace("/workspace", str(runtime)) for key, value in contract.items()}
        run(["sh", "-eu", "-c", contract["compile"]], app, env)
        database = "qualification_" + secrets.token_hex(10)
        # Override only the disposable snapshot. Preserve the shipped exploration
        # account, socket and database defaults and authentication behavior.
        user = output(["psql", "-d", "postgres", "-Atc", "select current_user"], text=True).strip()
        with (app / "config/runtime.exs").open("a") as config:
            config.write(f'\nconfig :business, Business.Repo, username: "{user}", database: "{database}"\n')
        try:
            run(["createdb", database], app, env)
            run(["mix", "ecto.migrate"], app, env)
            if not args.proof:
                env["SMOKE_EXPECTATION_PATH"] = str(root / "retained.json")
                run(["mix", "run", "scripts/qualification_seed.exs"], app, env)
                env["SMOKE_EXISTING_LEAD"] = (root / "retained.json").read_text()
            states = ["baseline"] if args.proof else ["baseline", "published"]
            # This host-wide lock remains held until the entire listener process
            # group has stopped, including on exceptions and interrupts.
            with open("/tmp/bedrock-port-4000.lock", "a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                for state in states:
                    with socket.socket() as available:
                        available.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                        available.bind(("127.0.0.1", 4000))
                    scene = app / "priv/published_site/scene.json"
                    if state == "baseline":
                        scene.unlink(missing_ok=True)
                    else:
                        shutil.copy2(ROOT / "test/fixtures/website_scene.json", scene)
                        (app / "priv/published_site/media.json").write_text('{"photos":{}}')
                        css = app / "priv/static/assets/published/site.css"
                        css.parent.mkdir(parents=True, exist_ok=True)
                        css.write_text("/* synthetic publication asset */ body { color: #17212b; background: #fff; }")
                        run(["mix", "assets.deploy"], app, env)
                    log = LOGS / f"service-{database}-{state}.log"
                    with log.open("w") as service_output:
                        server = None
                        try:
                            with defer_interrupts():
                                server = subprocess.Popen(["sh", "-eu", "-c", contract["service"]],
                                                          cwd=app, env=env, stdout=service_output, stderr=service_output,
                                                          start_new_session=True)
                            for _ in range(30):
                                if server.poll() is not None:
                                    raise RuntimeError(f"Listener failed; inspect {log}")
                                try:
                                    with urllib.request.urlopen("http://127.0.0.1:4000/health/ready", timeout=2) as response:
                                        if response.status == 200:
                                            break
                                except OSError:
                                    time.sleep(1)
                            else:
                                raise RuntimeError("Readiness timeout")
                            with urllib.request.urlopen("http://127.0.0.1:4000/", timeout=2) as response:
                                hrefs = re.findall(r'<link[^>]+href="([^"]+)"', response.read().decode())
                                print(f"{state}: HTTP stylesheet URLs {hrefs}", flush=True)
                            run(["sh", "-eu", "-c", contract["smoke"]], app, env)
                            print(f"{state}: actual HTTP/database smoke passed", flush=True)
                        finally:
                            if server is not None:
                                stop(server)
        finally:
            with defer_interrupts():
                run(["dropdb", "--if-exists", "--force", database], app, env)
                print(f"Removed database {database}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bedrock", type=Path)
    parser.add_argument("--list-checks", action="store_true",
                        help="Describe checks without source, builds or any qualification side effects")
    parser.add_argument("--bedrock-revision", help="Committed identity of a permitted git archive HEAD snapshot")
    parser.add_argument("--snapshot-parent", type=Path, default=ROOT / ".foundry",
                        help="Existing disposable parent owned by this run's observer")
    parser.add_argument("--proof", action="store_true", help="Smallest real prod boundary probe before full qualification")
    args = parser.parse_args()
    if args.list_checks:
        list_checks(args.proof)
    else:
        if args.bedrock is None:
            parser.error("the following arguments are required: --bedrock")
        for number in (signal.SIGINT, signal.SIGTERM):
            signal.signal(number, interrupted)
        qualify(args)
