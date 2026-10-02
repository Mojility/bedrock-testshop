"""Read immutable caller archives and observe only an isolated synthetic database."""

import hashlib
import json
from pathlib import Path
import subprocess
import uuid


def read(root, relative):
    path = root / relative
    data = path.read_bytes()
    print(f"{relative} sha256={hashlib.sha256(data).hexdigest()}")
    return data.decode()


starter = Path.cwd()
bedrock = Path('/tmp/postgres-contract-bedrock')
roost = Path('/tmp/postgres-contract-roost')
assert 'postgres 18\n' in read(starter, '.tool-versions')
assert 'needs.toolchain.outputs.postgres' in read(starter, '.github/workflows/build.yml')
assert 'image: postgres:16' in read(bedrock, '.github/workflows/integration.yml')
assert 'postgresql-16 bubblewrap' in (bedrock / '.github/workflows/integration.yml').read_text()
assert 'image: postgres:16' in read(roost, '.github/workflows/check.yml')
guest = read(roost, 'priv/cell/environment_guest.py')
assert "int(version) // 10000 != profile['postgres_major']" in guest
assert "raise ValueError('unexpected database version')" in guest
assert guest.index("raise ValueError('unexpected database version')") < guest.index("'pg_restore'")
qualification = read(roost, 'docs/development-environment-qualification.md')
assert 'PostgreSQL 18.6' in qualification
assert 'It reuses the qualified toolchain' in qualification
assert 'from PostgreSQL 15.17 to 18.6' in read(roost, 'docs/postgresql-18-maintenance.md')
assert 'RDS_POSTGRES_IMAGE' in read(roost, 'priv/cell/runner.py')

database = 'postgres_contract_' + uuid.uuid4().hex
subprocess.run(['createdb', database], check=True)
try:
    observed = subprocess.check_output(
        ['psql', '--no-psqlrc', '-d', database, '-Atc', 'SHOW server_version'], text=True
    ).strip()
    print(json.dumps({
        'starter_major': 18,
        'caller_ci_major': 16,
        'guest_and_rds_major_recorded_in_committed_sources': 18,
        'synthetic_workstation_server_version': observed,
        'finding_owner': 'Bedrock and Roost CI owners; Roost guest profile owns runtime selection',
        'live_hosting_observed': False,
    }, sort_keys=True))
finally:
    subprocess.run(['dropdb', database], check=True)
    print('Synthetic database removed; no application or customer data read.')
