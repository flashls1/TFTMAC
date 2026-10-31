#!/usr/bin/env python3
"""Actual build/verification isolation tests; no native runtime is launched."""
from __future__ import annotations

import copy
import io
import json
from pathlib import Path
import plistlib
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import turbo2_isolation as isolation


class IsolationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture_root = ROOT / '.build/turbo2-isolation-tests'
        cls.fixture_root.mkdir(parents=True, exist_ok=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=self.fixture_root)
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home'
        self.home.mkdir()
        (self.home / 'Desktop').mkdir()
        self.contract = isolation.load_contract()
        self.registry = json.loads((ROOT / 'ssot/runtime-modes.json').read_text())
        self.output = self.home / 'Desktop/TFT TURBO 2.app'
        for key, value in list(self.registry['modes']['turbo2'].items()):
            if isinstance(value, str) and value.startswith(str(Path.home()) + '/'):
                self.registry['modes']['turbo2'][key] = str(self.home) + value[len(str(Path.home())):]

    def inspect(self, output=None):
        return isolation.inspect_contract(self.contract, self.registry, output, self.home)

    def test_valid_contract_is_not_a_ready_runtime(self):
        report = self.inspect()
        self.assertEqual(report['isolation_contract'], 'PASS')
        self.assertTrue(report['build_allowed'])
        self.assertFalse(report['launch_allowed'])
        self.assertEqual(report['credential_access'], 'DEFERRED_TO_LOCAL_CODEX')
        self.assertFalse(self.output.exists())

    def test_original_apps_and_parent_child_paths_rejected(self):
        paths = [self.home / 'Desktop/TFT TURBO.app', self.home / 'Desktop/TFT Ranked.app',
                 self.home / 'Desktop', self.home / 'Desktop/TFT TURBO.app/child.app',
                 Path('/Applications/TFTMAC.app'), Path('/Applications/TFTMAC DEV.app')]
        for path in paths:
            with self.subTest(path=path), self.assertRaises(isolation.IsolationError):
                self.inspect(path)

    def test_relative_and_traversal_output_rejected(self):
        for path in [Path('TFT TURBO 2.app'), self.home / 'Desktop/../Desktop/TFT TURBO 2.app']:
            with self.subTest(path=path), self.assertRaises(isolation.IsolationError):
                self.inspect(path)

    def test_output_symlink_to_original_rejected(self):
        original = self.home / 'Desktop/TFT TURBO.app'
        original.mkdir()
        sentinel = original / 'sentinel'
        sentinel.write_text('unchanged')
        self.output.symlink_to(original, target_is_directory=True)
        with self.assertRaises(isolation.IsolationError):
            self.inspect()
        self.assertEqual(sentinel.read_text(), 'unchanged')

    def test_dangling_output_symlink_rejected(self):
        self.output.symlink_to(self.home / 'missing.app')
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_parent_symlink_cannot_redirect_runtime(self):
        parent = self.home / 'Library/Application Support/TFTMAC'
        parent.mkdir(parents=True)
        original = parent / 'InternalRuntime/StockShadow'
        original.mkdir(parents=True)
        (parent / 'Turbo2').symlink_to(original, target_is_directory=True)
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_plain_file_at_app_path_rejected(self):
        self.output.write_text('not an application')
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_changed_contract_root_cannot_reuse_original(self):
        self.contract['paths']['runtime_root'] = 'Library/Application Support/TFTMAC/InternalRuntime/StockShadow'
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_contract_traversal_rejected(self):
        self.contract['paths']['sdk_root'] = '../original/SDK'
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_same_or_nested_canonical_paths_detected(self):
        self.assertTrue(isolation._overlap(Path('/tmp/TFT TURBO.app'), Path('/tmp/tft turbo.app/Contents')))
        self.assertFalse(isolation._overlap(Path('/tmp/TFT TURBO.app'), Path('/tmp/TFT TURBO 2.app')))

    def test_existing_registry_port_collision_rejected(self):
        self.contract['ports']['adb_server'] = 5041
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_adjacent_guest_adb_port_is_reserved(self):
        self.registry['modes']['candidate']['console_port'] = 5599
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_duplicate_candidate_ports_rejected(self):
        self.contract['ports']['authenticated_controller'] = self.contract['ports']['adb_server']
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_odd_console_or_wrong_adjacent_port_rejected(self):
        original = copy.deepcopy(self.contract)
        for key, val in [('emulator_console', 5601), ('emulator_adb_transport', 5603)]:
            self.contract = copy.deepcopy(original)
            self.contract['ports'][key] = val
            with self.subTest(key=key), self.assertRaises(isolation.IsolationError):
                self.inspect()

    def test_boolean_port_and_out_of_range_rejected(self):
        for val in [True, 0, 65536, '5053']:
            self.contract['ports']['adb_server'] = val
            with self.subTest(value=val), self.assertRaises(isolation.IsolationError):
                self.inspect()

    def test_shared_exclusive_lease_cannot_be_split(self):
        self.contract['exclusive_lease_home_relative'] = 'Library/Application Support/TFTMAC/Turbo2/lease'
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_unauthenticated_controller_rejected(self):
        self.contract['controller']['authentication_required'] = False
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_old_bundle_identity_rejected(self):
        self.contract['application']['bundle_identifier'] = 'com.flashls1.tftmac.dev'
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_renamed_incumbent_bundle_rejected(self):
        contents = self.output / 'Contents'
        contents.mkdir(parents=True)
        (contents / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.flashls1.tftmac.dev'}))
        with self.assertRaises(isolation.IsolationError):
            isolation.require_candidate_bundle(self.output)

    def test_missing_candidate_bundle_rejected(self):
        with self.assertRaisesRegex(isolation.IsolationError, 'NOT_INSTALLED'):
            isolation.require_candidate_bundle(self.output)

    def test_false_ready_descriptor_does_not_enable_execution(self):
        self.contract['launch_state'] = 'enabled'
        with self.assertRaises(isolation.IsolationError):
            self.inspect()
        self.contract['launch_state'] = 'blocked_not_built'
        self.registry['modes']['turbo2']['launch_state'] = 'enabled'
        with self.assertRaises(isolation.IsolationError):
            self.inspect()

    def test_only_valid_stable_signing_identity_accepted(self):
        listing = '  1) ' + ('a' * 40) + ' "TFTMAC Local Code Signing"\n 1 valid identities found\n'
        self.assertEqual(isolation.parse_signing_identity(listing), isolation.SIGNING_IDENTITY)
        for invalid in ['0 valid identities found', '-', listing.replace('a' * 40, 'invalid'),
                        listing.replace('"\n', '" (CSSMERR_TP_NOT_TRUSTED)\n')]:
            with self.subTest(invalid=invalid), self.assertRaises(isolation.IsolationError):
                isolation.parse_signing_identity(invalid)

    def test_signing_lookup_failure_cannot_fall_back(self):
        with patch.object(subprocess, 'run', side_effect=OSError('unavailable')):
            with self.assertRaises(isolation.IsolationError):
                isolation.required_signing_identity()

    def test_port_probe_closes_socket_and_reports_busy_owner(self):
        import socket
        with socket.socket() as owner:
            owner.bind(('127.0.0.1', 0))
            port = owner.getsockname()[1]
            self.assertEqual(isolation.observe_ports({'test': port})['test'], 'UNAVAILABLE')
        self.assertIn('AVAILABLE_AT_OBSERVATION', isolation.observe_ports({'test': port})['test'])

    def test_builder_guard_runs_before_effects_or_seed_reads(self):
        argv = [str(ROOT / 'scripts/build-turbo-app.py'), '--output', str(Path.home() / 'Desktop/TFT TURBO.app')]
        with patch.object(sys, 'argv', argv), patch.object(sys, 'stderr', io.StringIO()) as error:
            with patch.object(subprocess, 'run', side_effect=AssertionError('process started')):
                with patch.object(shutil, 'rmtree', side_effect=AssertionError('deletion attempted')):
                    with patch.object(Path, 'read_bytes', side_effect=AssertionError('private read attempted')):
                        with patch.object(Path, 'mkdir', side_effect=AssertionError('filesystem mutation')):
                            with self.assertRaises(SystemExit) as stopped:
                                runpy.run_path(str(ROOT / 'scripts/build-turbo-app.py'), run_name='__main__')
        self.assertEqual(stopped.exception.code, 2)
        self.assertIn('originals are protected', error.getvalue())

    def run_cli(self, command):
        return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=20)

    def test_actual_builder_preflight_reads_no_seed(self):
        result = self.run_cli([sys.executable, '-B', 'scripts/build-turbo-app.py', '--preflight'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)['build_allowed'])
        rejected = self.run_cli([sys.executable, '-B', 'scripts/build-turbo-app.py', '--seed', '/NOT-AN-INPUT'])
        self.assertEqual(rejected.returncode, 2)
        self.assertIn('unrecognized arguments', rejected.stderr)

    def test_actual_builder_rejects_original_output(self):
        result = self.run_cli([sys.executable, '-B', 'scripts/build-turbo-app.py', '--output',
                               str(Path.home() / 'Desktop/TFT TURBO.app')])
        self.assertEqual(result.returncode, 2)
        self.assertIn('originals are protected', result.stderr)

    def test_actual_verifier_requires_exact_candidate(self):
        for args in [[], ['--app', str(Path.home() / 'Desktop/TFT TURBO.app')],
                     ['--app', 'TFT TURBO 2.app']]:
            result = self.run_cli(['/bin/zsh', 'scripts/verify-turbo-build.command', *args])
            with self.subTest(args=args):
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertNotIn('Checking Gate', result.stdout)
                self.assertNotIn('Running test suite', result.stdout)

    def test_actual_verifier_preflight_is_not_live_acceptance(self):
        result = self.run_cli(['/bin/zsh', 'scripts/verify-turbo-build.command', '--preflight'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['native_integration'], 'BUILD_ONLY_RUNTIME_PENDING')

    def test_exclusive_publish_never_overwrites_existing_target(self):
        source, target = self.home / 'source', self.home / 'target'
        source.mkdir(); target.mkdir()
        (source / 'new').write_text('new')
        (target / 'old').write_text('preserved')
        with self.assertRaises(OSError):
            isolation.publish_exclusively(source, target)
        self.assertEqual((target / 'old').read_text(), 'preserved')
        self.assertTrue((source / 'new').exists())

    def test_exclusive_publish_promotes_complete_new_target(self):
        source, target = self.home / 'source', self.home / 'target'
        source.mkdir(); (source / 'content').write_text('complete')
        isolation.publish_exclusively(source, target)
        self.assertEqual((target / 'content').read_text(), 'complete')
        self.assertFalse(source.exists())

    def test_stage_must_be_owned_private_and_exact(self):
        stage = self.home / 'Desktop/.tft-turbo2-build-fixture'
        stage.mkdir(mode=0o700)
        candidate = stage / 'TFT TURBO 2.app'
        self.assertEqual(isolation.staged_candidate_path(candidate, self.home), candidate)
        stage.chmod(0o755)
        with self.assertRaises(isolation.IsolationError):
            isolation.staged_candidate_path(candidate, self.home)

    def test_native_identity_mismatch_cannot_be_hidden_in_descriptor(self):
        self.registry['modes']['turbo2']['sdk_root'] = '/old/sdk'
        with self.assertRaises(isolation.IsolationError):
            self.inspect()


if __name__ == '__main__':
    unittest.main(verbosity=2)
