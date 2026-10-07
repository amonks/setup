"""Cron command and reporting regressions; all jobs and check-ins are fake."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

WRAPPER = Path(__file__).resolve().parents[2] / 'bin/cronwrap'


class CronwrapTests(unittest.TestCase):
    def invoke(self, job_code, curl_code=0, summary='FAILED: access denied', args=()):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            curl = directory / 'curl'
            curl.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "$CURL_ARGS"\nexit ' + str(curl_code) + '\n')
            curl.chmod(0o755)
            sleep = directory / 'sleep'
            sleep.write_text('#!/bin/sh\nexit 0\n'); sleep.chmod(0o755)
            job = directory / 'job with spaces'
            job.write_text('#!/bin/sh\nprintf "argument: %s\\n" "$1"\nprintf "%s\\n" ' + repr('backup-summary: ' + summary) + '\nexit ' + str(job_code) + '\n')
            job.chmod(0o755)
            env = dict(os.environ, PATH=tmp + ':' + os.environ['PATH'], CURL_ARGS=str(directory/'curl-args'))
            result = subprocess.run([str(WRAPPER), str(directory/'logs'), 'TEST', str(job), *args], env=env, capture_output=True, text=True)
            curl_args = (directory/'curl-args').read_text() if (directory/'curl-args').exists() else ''
            return result.returncode, curl_args, result.stdout

    def test_failure_exit_summary_and_argument_boundaries(self):
        code, args, output = self.invoke(23, args=('one argument',))
        self.assertEqual(code, 23)
        self.assertIn('s=23\n', args)
        self.assertIn('m=FAILED: access denied\n', args)
        self.assertIn('argument: one argument\n', output)
        self.assertIn('--fail\n', args)

    def test_http_failure_is_not_success(self):
        code, args, _ = self.invoke(0, curl_code=22)
        self.assertEqual(code, 1)
        self.assertEqual(args.count('--fail\n'), 3)

    def test_overlap_does_not_check_in(self):
        code, args, _ = self.invoke(75, summary='SKIPPED: another backup')
        self.assertEqual(code, 75)
        self.assertEqual(args, '')


class CronEntryTests(unittest.TestCase):
    def test_port_entry_uses_command_and_argument(self):
        # Root's MacPorts entry must pass argv, just like the backup caller.
        command = '"{wrapper}" "{logs}" TEST "{port}" selfupdate'
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            port = directory / 'port'
            port.write_text('#!/bin/sh\n[ "$#" -eq 1 ] && [ "$1" = selfupdate ]\n')
            port.chmod(0o755)
            curl = directory / 'curl'
            curl.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$CURL_ARGS"\n')
            curl.chmod(0o755)
            result = subprocess.run(
                ['/bin/sh', '-c', command.format(wrapper=WRAPPER, logs=directory/'logs', port=port)],
                env=dict(os.environ, PATH=tmp+':'+os.environ['PATH'], CURL_ARGS=str(directory/'curl-args')),
                text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('s=0\n', (directory/'curl-args').read_text())


if __name__ == '__main__':
    unittest.main()
