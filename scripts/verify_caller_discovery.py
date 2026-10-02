#!/usr/bin/env python3
"""Regress discovery through the real CLI with qualification side effects denied.

Run with: python3 scripts/verify_caller_discovery.py
Python audit hooks reject child processes, network/listener operations and
filesystem mutations inside the CLI process; no qualification helpers are mocked.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'scripts/qualify_callers.py'
AUDIT = '''
import os
import sys

def deny_side_effects(event, args):
    if (event.startswith(('subprocess.', 'socket.', 'os.exec', 'os.spawn'))
            or event in {'os.system', 'os.mkdir', 'os.remove', 'os.rmdir',
                         'os.rename', 'os.link', 'os.symlink', 'os.truncate',
                         'os.chmod', 'os.chown', 'os.utime', 'tempfile.mkdtemp',
                         'tempfile.mkstemp', 'fcntl.flock'}):
        raise RuntimeError('Discovery side effect: ' + event)
    if event == 'open':
        _, mode, flags = args
        if (mode and any(char in mode for char in 'wax+')) or flags & (
                os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND):
            raise RuntimeError('Discovery file write')

sys.addaudithook(deny_side_effects)
'''


class CallerDiscoveryTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='discovery-regression-')
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        (self.directory / 'sitecustomize.py').write_text(AUDIT)
        self.env = dict(os.environ, PYTHONPATH=str(self.directory),
                        PYTHONDONTWRITEBYTECODE='1', PATH='')

    def cli(self, *arguments):
        return subprocess.run(
            [sys.executable, '-B', str(CLI), *arguments], cwd=self.directory,
            env=self.env, text=True, capture_output=True, timeout=10)

    def inventory(self, *arguments):
        result = self.cli('--list-checks', *arguments)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertIn('inventory is not passing behavioral evidence', result.stdout)
        return result.stdout

    def test_full_inventory_describes_actual_behavior_without_caller_source(self):
        inventory = self.inventory()
        for description in (
                'cold-preparation:', 'dev/test/prod', 'cached-preparation:',
                'Bootstrap/Preparation', 'MIX_ENV=prod', 'baseline:', 'published:',
                'digested URLs', 'text/css', 'HTTP 403', 'no database write',
                'anonymous-staff:', 'stored name, phone, email and request message',
                'magic-link token', 'authenticated staff HTTP reads',
                'before startup', 'source, status, notes, legacy ID, inserted_at and seen_at',
                'new and retained enquiries', 'every listener process',
                'shared port lock', 'drop the synthetic database', 'remove snapshots',
                'SIGINT and SIGTERM'):
            with self.subTest(description=description):
                self.assertIn(description, inventory)

    def test_proof_inventory_reports_smaller_path_and_its_retained_checks(self):
        inventory = self.inventory('--proof')
        self.assertIn('prod-only, baseline only', inventory)
        self.assertIn('no cached preparation or pre-start retained seed', inventory)
        for omitted in ('cached-preparation:', 'preparation-environments:',
                        'published:', 'retained-before-startup:'):
            self.assertNotIn(omitted, inventory)
        for included in ('retained-integrity:', 'authenticated-reads:', 'cleanup:'):
            self.assertIn(included, inventory)

    def test_discovery_ignores_unavailable_execution_inputs_without_creating_them(self):
        missing = self.directory / 'missing'
        self.inventory('--bedrock', str(missing), '--bedrock-revision', 'invalid',
                       '--snapshot-parent', str(missing))
        self.assertFalse(missing.exists())
        self.assertEqual(sorted(path.name for path in self.directory.iterdir()),
                         ['sitecustomize.py'])

    def test_execution_still_requires_caller_source_for_both_paths(self):
        for arguments in ((), ('--proof',)):
            with self.subTest(arguments=arguments):
                result = self.cli(*arguments)
                self.assertEqual(result.returncode, 2)
                self.assertIn('required: --bedrock', result.stderr)
                self.assertNotIn('Discovery side effect', result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
