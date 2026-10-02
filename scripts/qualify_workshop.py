#!/usr/bin/env python3
"""Qualify candidate starter source with committed Workshop owning gate code.

Supply a permitted git archive HEAD snapshot and its immutable revision. Only
synthetic databases are used. This is command compatibility, not guest isolation.
The owning Runner, Command and broker argv/environment constructors are executed;
none of their gates or receipts are replaced with a starter approximation.
"""
import argparse
import io
import tarfile
from contextlib import contextmanager
import fcntl
import hashlib
import importlib.util
import http.client
import html
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import socket
import subprocess
import tempfile
import urllib.request
import time
import sys

sys.dont_write_bytecode = True

import qualify_callers as callers


def manifest(root, names):
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
            for name in names if (root / name).is_file()}


def committed_archive(repository, revision):
    """Resolve immutable Git bytes, rather than trusting an archive label."""
    if not re.fullmatch('[a-f0-9]{40}', revision):
        raise ValueError('Source identity requires a full committed revision')
    resolved = callers.output(['git', 'rev-parse', revision + '^{commit}'],
                              cwd=repository, text=True).strip()
    if resolved != revision:
        raise ValueError('Source identity must name the commit itself')
    archive = callers.output(['git', 'archive', revision], cwd=repository)
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        expected = {entry.name: hashlib.sha256(source.extractfile(entry).read()).hexdigest()
                    for entry in source if entry.isfile()}
    return archive, expected


def verify_source(root, expected):
    observed = manifest(root, expected)
    changed = sorted(name for name, digest in expected.items() if observed.get(name) != digest)
    if changed:
        raise ValueError('Executing source differs from committed identity: ' + ', '.join(changed))
    return observed


@contextmanager
def preserved_callers(identities, workshop, bedrock, report, path):
    try:
        yield
    finally:
        report['caller_source_preserved'] = {
            name: verify_source(workshop if name == 'workshop' else bedrock, identity['manifest']) == identity['manifest']
            for name, identity in identities.items()}
        path.write_text(json.dumps(report, indent=2) + '\n')


@contextmanager
def monitored_snapshot(report, path):
    try:
        with callers.disposable_snapshot(Path('/tmp')) as temporary:
            report['snapshot'] = str(temporary)
            yield temporary
    finally:
        report['cleanup']['snapshot_removed'] = not Path(report['snapshot']).exists()
        path.write_text(json.dumps(report, indent=2) + '\n')


def check_local_login(context, database, env):
    """Verify the isolated owner session through real HTTP and session storage."""
    # The guest terminates TLS at its edge. Like Business.Smoke, this
    # off-guest HTTP probe carries the returned cookie explicitly; it does
    # not weaken Secure/Partitioned policy or claim browser HTTPS behavior.
    browser = http.client.HTTPConnection('127.0.0.1', 4000, timeout=10)
    try:
        browser.request('GET', '/users/log-in')
        response = browser.getresponse()
        response.read()
        assert response.status == 302 and response.getheader('location') == '/app/leads'
        cookie = response.getheader('set-cookie')
        assert cookie and cookie.startswith('__Host-business_exploration=')
        for attribute in ('secure', 'httponly', 'samesite=none', 'partitioned'):
            assert attribute in cookie.lower(), 'Missing session security attribute: ' + attribute
        browser.request('GET', '/app/leads', headers={'Cookie': cookie.split(';', 1)[0]})
        response = browser.getresponse()
        body = html.unescape(response.read().decode())
        assert response.status == 200
    finally:
        browser.close()
    retained = json.loads((context / 'retained.json').read_text())
    for field in ('name', 'phone', 'email', 'message', 'notes'):
        assert retained[field] in body, 'Isolated staff read lost ' + field
    observation = callers.output(
        ['psql', '-d', database, '-Atc',
         "select role || ':' || exists(select 1 from users_tokens t where t.user_id=u.id and t.context='session')::text from users u where email='workspace-owner@example.invalid'"],
        env=env, text=True).strip()
    assert observation == 'owner:true', 'Owner session not stored'
    evidence = {'request': ['GET /users/log-in', 'GET /app/leads'], 'status': 200,
                'cookie_created': True, 'cookie_attributes': ['Secure', 'HttpOnly', 'SameSite=None', 'Partitioned'],
                'loopback_cookie_transport': 'explicit header; guest TLS edge not qualified',
                'database_session': observation,
                'retained_staff_fields': ['name', 'phone', 'email', 'message', 'notes']}
    (context / 'local-login.json').write_text(json.dumps(evidence, indent=2) + '\n')
    return evidence


def qualify(args):
    workshop = args.workshop.resolve()
    if not re.fullmatch('[a-f0-9]{40}', args.workshop_revision):
        raise ValueError('Workshop archive requires a full committed revision')
    identities = {}
    for name, root, repository, revision in (
            ('workshop', workshop, args.workshop_repository, args.workshop_revision),
            ('bedrock', args.bedrock, args.bedrock_repository, args.bedrock_revision)):
        _, expected = committed_archive(repository, revision)
        verify_source(root, expected)
        identities[name] = {'revision': revision, 'manifest': expected}
    candidate_archive, candidate_manifest = committed_archive(callers.ROOT, args.starter_revision)
    report_path = args.report.resolve()
    context = Path(tempfile.mkdtemp(prefix='workshop-', dir=callers.LOGS))
    report = {'workshop': args.workshop_revision,
              'starter': args.starter_revision, 'source_identities': identities,
              'context': str(context), 'gates': [], 'cleanup': {}}
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(('AWS_', 'OPENAI_', 'ANTHROPIC_', 'DATABASE_', 'EXPLORATION_',
                                  'WORKSHOP_', 'SMOKE_'))}
    pinned = dict(line.split() for line in (callers.ROOT / '.tool-versions').read_text().splitlines())
    bins = [callers.output(['mise', 'where', package + '@' + pinned[package]], text=True).strip() + '/bin'
            for package in ('elixir', 'erlang')]
    env['PATH'] = ':'.join(bins + [env['PATH']])
    env.update(ERL_FLAGS='+S 4:4', AWS_EC2_METADATA_DISABLED='true',
               SECRET_KEY_BASE=secrets.token_hex(64), MAIL_ADAPTER='disabled',
               LEAD_NOTIFICATIONS='false', EXPLORATION_HOST='qualification.invalid',
               EXPLORATION_PARENT_ORIGIN='https://qualification.mybedrock.ca')
    user = callers.output(['psql', '-d', 'postgres', '-Atc', 'select current_user'], text=True).strip()
    nonce = secrets.token_hex(10)
    databases = ['workshop_' + nonce, 'workshop_test_' + nonce]
    env.update(WORKSHOP_QUALIFICATION_DB_USER=user,
               WORKSHOP_QUALIFICATION_DATABASE=databases[0],
               WORKSHOP_QUALIFICATION_TEST_DATABASE=databases[1],
               WORKSHOP_QUALIFICATION_CONTEXT=str(context))
    report['environment'] = {key: value for key, value in env.items()
                             if key.startswith(('WORKSHOP_', 'EXPLORATION_', 'ERL_', 'MAIL_', 'LEAD_', 'AWS_'))}
    report['environment']['SECRET_KEY_BASE'] = '<fresh synthetic value; redacted>'
    # A committed Workshop archive omits derived packaging inputs. Rehydrate
    # only canonical bytes, using its producer's validation and provenance.
    spec = importlib.util.spec_from_file_location('workshop_guidance', workshop / 'scripts/guidance.py')
    guidance = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(guidance)
    if not re.fullmatch('[a-f0-9]{40}', args.bedrock_revision):
        raise ValueError('Bedrock archive requires a full committed revision')
    meta = (args.bedrock / guidance.META_MODEL['source']).read_bytes()
    guidance.validate(meta)
    profile_revision = callers.output(
        ['git', 'ls-remote', guidance.PHOENIX_PROFILE['repository'], 'refs/heads/main'], text=True).split()[0]
    profile = urllib.request.urlopen(
        'https://raw.githubusercontent.com/svetzal/guidelines/' + profile_revision + '/' +
        guidance.PHOENIX_PROFILE['source'], timeout=60).read()
    for origin, data in ((guidance.META_MODEL, meta), (guidance.PHOENIX_PROFILE, profile)):
        target = workshop / origin['destination']
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    guidance_lock = {'version': 1, **guidance.provenance(guidance.META_MODEL, args.bedrock_revision, meta),
                     'profiles': {'phoenix-v1': guidance.provenance(guidance.PHOENIX_PROFILE, profile_revision, profile)}}
    (workshop / guidance.LOCK).write_text(json.dumps(guidance_lock, indent=2) + '\n')
    guidance.check(workshop)
    report['bedrock'] = args.bedrock_revision
    report['guidance'] = guidance_lock
    report['workshop_files'] = {str(path.relative_to(workshop)): hashlib.sha256(path.read_bytes()).hexdigest()
                                for pattern in ('lib/workshop_executive/*.ex', 'priv/host/*', 'scripts/qualify_starter.*')
                                for path in workshop.glob(pattern) if path.is_file()}
    with preserved_callers(identities, workshop, args.bedrock, report, report_path), monitored_snapshot(report, report_path) as temporary:
        app = temporary / 'app'
        app.mkdir()
        callers.output(['tar', '-x', '-C', str(app)], input=candidate_archive)
        before = verify_source(app, candidate_manifest)
        report['candidate_source'] = hashlib.sha256(candidate_archive).hexdigest()
        report['candidate_archive_sha256'] = report['candidate_source']
        report['source_manifest'] = before
        report['snapshot'] = str(temporary)
        report_path.write_text(json.dumps(report, indent=2) + '\n')
        # Preparation caches are copied, never linked to the candidate source.
        for name in ('deps', '_build', '.bedrock-tools', 'priv/plts'):
            if (callers.ROOT / name).exists():
                shutil.copytree(callers.ROOT / name, app / name, symlinks=True)
        with open('/tmp/bedrock-port-4000.lock', 'a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                with socket.socket() as available:
                    available.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    available.bind(('127.0.0.1', 4000))
                for database in databases:
                    callers.run(['createdb', database], app, env)
                for environment in ('dev', 'test', 'prod'):
                    callers.run(['mix', 'deps.get'], app, dict(env, MIX_ENV=environment))
                    callers.run(['mix', 'compile'], app, dict(env, MIX_ENV=environment))
                callers.run(['mix', 'assets.setup'], app, dict(env, MIX_ENV='prod'))
                # Real Workshop release advisory revision, with no suppression policy.
                revision = re.search(r'elixir-security-advisories.git ([a-f0-9]{40})',
                                     (workshop / 'Dockerfile').read_text()).group(1)
                advisory = temporary / 'advisories'
                archive = urllib.request.urlopen(
                    'https://codeload.github.com/mirego/elixir-security-advisories/tar.gz/' + revision,
                    timeout=60).read()
                advisory.mkdir()
                callers.output(['tar', '-xz', '--strip-components=1', '-C', str(advisory)], input=archive)
                (advisory / 'REVISION').write_text(revision + '\n')
                env['WORKSHOP_QUALIFICATION_ADVISORIES'] = str(advisory)
                report['advisory_revision'] = revision
                # Seed before any server starts using the owner's off-guest DB overlay.
                runtime = workshop / 'priv/host/qualification_runtime.exs'
                env['SMOKE_EXPECTATION_PATH'] = str(context / 'retained.json')
                callers.run(['mix', 'do', 'run', '--no-start', str(runtime), '+',
                             'ecto.migrate', '+', 'run', 'scripts/qualification_seed.exs'],
                            app, dict(env, MIX_ENV='prod', CUSTOMER_EXPLORATION='true'))
                env['SMOKE_EXISTING_LEAD'] = (context / 'retained.json').read_text()
                env.update(HEX_OFFLINE='1', PGHOST='/var/run/postgresql', PGUSER=user, PGDATABASE=databases[0])
                spec = importlib.util.spec_from_file_location('protected_broker', workshop / 'priv/host/broker.py')
                broker = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(broker)
                report['environment'].update(HEX_OFFLINE='1', PGHOST='/var/run/postgresql', PGUSER=user, PGDATABASE=databases[0])
                (context / 'context.json').write_text(json.dumps({'root': str(app), 'environment': env}))
                os.chmod(context / 'context.json', 0o600)
                callers.run(['mix', 'deps.get'], workshop, dict(env, MIX_ENV='dev', HEX_OFFLINE='0'))
                callers.run(['mix', 'run', '--no-start', str(callers.ROOT / 'scripts/check_workshop_boundaries.exs')],
                            workshop, dict(env, MIX_ENV='dev'))
                try:
                    callers.run(['mix', 'run', '--no-start', 'scripts/qualify_starter.exs'],
                                workshop, dict(env, MIX_ENV='dev'))
                except subprocess.CalledProcessError as error:
                    report['runner_exit'] = error.returncode
                else:
                    report['runner_exit'] = 0
                gates = context / 'gates.json'
                if gates.exists():
                    for result in json.loads(gates.read_text()):
                        receipt = result['receipt']
                        report['gates'].append({'name': result['gate'],
                                                'status': receipt['status'],
                                                'argv': receipt.get('argv'),
                                                'environment': broker.command_environment(result['gate']) if result['gate'] in broker.COMMANDS else {},
                                                'exit_code': receipt.get('exit_status'),
                                                'log': str(context / (result['gate'] + '.artifact.json'))})
                if any(gate['name'] == 'boot' and gate['status'] == 'passed' for gate in report['gates']):
                    report['isolated_login'] = check_local_login(context, databases[0], env)
                report['source_preserved'] = before == manifest(app, before.keys())
                report['mix_lock_preserved'] = before['mix.lock'] == hashlib.sha256((app / 'mix.lock').read_bytes()).hexdigest()
                # Stop protected boot before the independent owner-managed local path.
                for path in context.glob('*.pid'):
                    if callers.group_running(int(path.read_text())):
                        stop_pid(int(path.read_text()))
                local = temporary / 'local'
                shutil.copytree(app, local, symlinks=True)
                with (local / 'config/runtime.exs').open('a') as config:
                    config.write('\nconfig :business, Business.Repo, username: ' + json.dumps(user) +
                                 ', database: ' + json.dumps(databases[0]) + '\n')
                report['local_database_remap'] = 'Separate disposable copy; only local socket role and database changed'
                expression = ('System.put_env("MIX_ENV", "prod"); '
                              'for name <- ["boot", "smoke"] do '
                              '{:ok, result} = WorkshopExecutive.LocalCommand.run(name, '
                              '[binding: %{"source_root" => System.fetch_env!("STARTER_ROOT")}, local_command_timeout: 600_000]); '
                              'IO.inspect(result); if result["status"] != "passed", do: System.halt(1); end')
                try:
                    callers.run(['mix', 'run', '--no-start', '-e', expression], workshop,
                                dict(env, MIX_ENV='dev', CUSTOMER_EXPLORATION='true', STARTER_ROOT=str(local)))
                    report['local_smoke'] = 'passed'
                except subprocess.CalledProcessError as error:
                    report['local_smoke'] = {'exit_code': error.returncode}
            finally:
                # A first interrupt can arrive during normal final cleanup.
                # Finish every owned resource before unwinding the port lock;
                # disposable_snapshot separately protects snapshot removal.
                with callers.defer_interrupts():
                    for path in context.glob('*.pid'):
                        stop_pid(int(path.read_text()))
                    report['cleanup']['remaining_processes'] = [int(path.read_text()) for path in context.glob('*.pid')
                                                               if callers.group_running(int(path.read_text()))]
                    cleanup_errors = []
                    for database in databases:
                        try:
                            callers.run(['dropdb', '--if-exists', '--force', database], app, env)
                        except subprocess.CalledProcessError as error:
                            cleanup_errors.append({'database': database, 'exit_code': error.returncode})
                    report['cleanup']['errors'] = cleanup_errors
                    report['cleanup']['database_query'] = callers.output(
                        ['psql', '-d', 'postgres', '-Atc',
                         "select datname from pg_database where datname in ('" + "','".join(databases) + "')"], text=True).strip()
                    (context / 'context.json').unlink(missing_ok=True)
                    report_path.write_text(json.dumps(report, indent=2) + '\n')
    report['cleanup']['snapshot_removed'] = not Path(report['snapshot']).exists()
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    if (report.get('runner_exit') != 0 or report.get('local_smoke') != 'passed' or not report.get('isolated_login')
            or not report.get('source_preserved') or not report.get('mix_lock_preserved')
            or report['cleanup'].get('errors') or report['cleanup'].get('database_query')
            or report['cleanup'].get('remaining_processes') or not report['cleanup'].get('snapshot_removed')):
        raise RuntimeError('Qualification failed; inspect ' + str(report_path))


def stop_pid(pid):
    """Wait for all owned group members before releasing the shared port lock."""
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(pid, sig)
        except ProcessLookupError:
            return
        deadline = time.monotonic() + 10
        while callers.group_running(pid) and time.monotonic() < deadline:
            time.sleep(0.05)
    while callers.group_running(pid):
        time.sleep(0.05)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workshop', type=Path, required=True)
    parser.add_argument('--bedrock', type=Path, required=True)
    parser.add_argument('--bedrock-revision', required=True)
    parser.add_argument('--workshop-revision', required=True)
    parser.add_argument('--workshop-repository', type=Path, required=True)
    parser.add_argument('--bedrock-repository', type=Path, required=True)
    parser.add_argument('--starter-revision', required=True)
    parser.add_argument('--report', type=Path, default=callers.ROOT / '.foundry/workshop.json')
    for number in (signal.SIGINT, signal.SIGTERM):
        signal.signal(number, callers.interrupted)
    qualify(parser.parse_args())
