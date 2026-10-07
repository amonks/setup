"""Regression checks for backup safety and reporting; never contacts Thor or DMS."""
import contextlib
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location('backup', Path(__file__).parents[1] / 'backup-mac-to-thor-run.py')
backup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(backup)


class BackupTests(unittest.TestCase):
    def command(self, body):
        return [sys.executable, '-c', body]

    def test_failure_preserves_freshness_and_explains_gap(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            directory = Path(tmp)
            self.assertEqual(backup.run(directory, self.command("print('backup-rsync-exit: 0')")), 0)
            state_path = directory / 'backup-mac-to-thor.status.json'
            good = json.loads(state_path.read_text())['last_complete_at']
            body = """
import sys
print('backup-stage: rsync')
print('rsync: [sender] opendir "/Users/test/Library/private" failed: Operation not permitted (1)')
print('Number of regular files transferred: 12')
print('Total bytes sent: 3M')
print('backup-rsync-exit: 23')
sys.exit(23)
"""
            self.assertEqual(backup.run(directory, self.command(body)), 23)
            failed = json.loads(state_path.read_text())
            self.assertEqual(failed['last_complete_at'], good)
            self.assertIsNotNone(failed['last_transfer_completed_at'])
            self.assertEqual(failed['counts']['access_denied'], 1)
            self.assertEqual(len(failed['new_issues']), 1)
            backup.run(directory, self.command(body))
            self.assertEqual(json.loads(state_path.read_text())['new_issues'], [])

    def test_overlap_neither_starts_worker_nor_refreshes_state(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            directory = Path(tmp)
            with (directory / 'backup-mac-to-thor.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.assertEqual(backup.run(directory, self.command('raise Exception()')), 75)
                self.assertFalse((directory / 'backup-mac-to-thor.status.json').exists())

    def test_deadline_kills_descendants_and_releases_lock(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            directory = Path(tmp)
            marker = directory / 'orphan-wrote'
            child = f'import time; from pathlib import Path; time.sleep(1); Path({str(marker)!r}).touch()'
            body = f'import subprocess,sys,time; subprocess.Popen([sys.executable,"-c",{child!r}]); time.sleep(30)'
            self.assertEqual(backup.run(directory, self.command(body), timeout=0.1), 124)
            time.sleep(1.1)
            self.assertFalse(marker.exists())
            self.assertEqual(backup.run(directory, self.command('pass')), 0)

    def test_vanished_source_differs_from_missing_destination(self):
        report = backup.Report()
        report.consume('file has vanished: "/Users/test/cache/temp"')
        report.consume('file has vanished: "/data/tank/mirror/test/temp"')
        self.assertEqual(report.counts, {'source_vanished': 1, 'destination_vanished': 1})
        self.assertEqual(len(report.issues), 1)

    def test_worker_preserves_filters_and_only_retries_transport(self):
        with mock.patch.object(backup, 'configuration', return_value=('brigid','ajm',['node_modules'],['mnt'])), \
             mock.patch.object(backup.time, 'sleep') as sleep, \
             mock.patch.object(backup.subprocess, 'call', side_effect=[255,24]) as call, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(backup.worker(), 0)
            self.assertEqual(call.call_count, 2)
            sleep.assert_called_once_with(30)
            args = call.call_args.args[0]
            self.assertNotIn('--ignore-errors', args)
            self.assertIn('protect /.zfs', args)
            self.assertLess(args.index('/Library/'), args.index('/Library/*'))
            self.assertIn('--timeout=300', args)
            self.assertEqual(args[-1], 'thor:/data/tank/mirror/brigid/ajm')
        with mock.patch.object(backup, 'configuration', return_value=('brigid','ajm',[],[])), \
             mock.patch.object(backup.subprocess, 'call', return_value=23) as call, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(backup.worker(), 23)
            call.assert_called_once()

    def test_no_whole_home_preread_blocks_the_transfer(self):
        with mock.patch.object(backup, 'configuration', return_value=('brigid','ajm',[],[])), \
             mock.patch.object(backup.subprocess, 'call', return_value=0) as call, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(backup.worker(), 0)
            call.assert_called_once()
            self.assertEqual(call.call_args.args[0][0], '/opt/local/bin/rsync')

    def test_rsync_mirrors_selected_trees_with_exclusions_and_snapshot_protection(self):
        # Exercise rsync's first-match filter semantics against real trees. Only
        # the captured command's two endpoints change; neither can reach Thor.
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'source'
            destination = Path(tmp) / 'destination'
            source.mkdir()
            destination.mkdir()
            included = {
                'Documents/note.txt',
                'Library/Application Support/App/settings',
                'Library/Keychains/keychain',
                'Library/Preferences/app.plist',
            }
            excluded = {
                'node_modules/package/index.js',
                'Library/Application Support/App/node_modules/package/index.js',
                'Library/Application Support/App/tailscaled.state',
                'Library/Keychains/.DS_Store',
                'Library/Preferences/.DS_Store',
                'Library/Application Support/FileProvider/private',
                'Library/Caches/cache',
                'mnt/file',
            }
            for relative in included | excluded:
                for root in (source, destination):
                    path = root / relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('current' if root == source else 'stale')
            snapshot = destination / '.zfs/snapshot/retained/file'
            snapshot.parent.mkdir(parents=True)
            snapshot.write_text('snapshot')
            (destination / 'deleted-at-source').write_text('stale')
            with mock.patch.object(backup, 'configuration', return_value=(
                    'brigid', 'ajm', ['node_modules', 'tailscaled.state', '.DS_Store'],
                    ['Library', 'mnt', '.zfs'])), \
                 mock.patch.object(backup.subprocess, 'call', return_value=0) as call, \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(backup.worker(), 0)
                command = call.call_args.args[0]
            command[-2:] = [str(source) + '/', str(destination) + '/']
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            actual = {str(path.relative_to(destination))
                      for path in destination.rglob('*') if path.is_file()}
            self.assertEqual(actual, included | {'.zfs/snapshot/retained/file'})
            for relative in included:
                self.assertEqual((destination / relative).read_text(), 'current')
            self.assertEqual(snapshot.read_text(), 'snapshot')

    def test_hydration_helper_preserves_traversal_failure(self):
        helper = Path.home()/'.config/fish/functions/materialize-icloud.fish'
        command = f'source "{helper}"; function fd; return 5; end; materialize-icloud ~; exit $status'
        result = subprocess.run(['/opt/local/bin/fish', '-c', command], capture_output=True)
        self.assertEqual(result.returncode, 5)



if __name__ == '__main__':
    unittest.main()
