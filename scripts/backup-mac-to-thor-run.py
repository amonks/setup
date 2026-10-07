#!/usr/bin/python3
"""Serialize and supervise the home mirror; retain an actionable status beside its log."""
import collections
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import time


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds')


class Report:
    def __init__(self, on_stage=None):
        self.on_stage = on_stage
        self.stage = 'starting'
        self.rsync_exit = None
        self.counts = collections.Counter()
        self.issues = set()
        self.samples = []
        self.stats = {}
        self.retries = 0

    def consume(self, line):
        if line.startswith('backup-stage: '):
            self.stage = line.split(': ', 1)[1]
            if self.on_stage:
                self.on_stage(self.stage)
        elif line.startswith('backup-rsync-exit: '):
            self.rsync_exit = int(line.split(': ', 1)[1])
        elif line.startswith('backup-retry: '):
            self.retries += 1
        for key in ('Number of regular files transferred', 'Total bytes sent', 'Total file size'):
            if line.startswith(key + ': '):
                self.stats[key] = line.split(': ', 1)[1]
        kind = None
        if line.startswith('backup-error:'):
            kind = 'job_error'
        elif line.startswith('file has vanished:'):
            kind = 'destination_vanished' if '"/data/' in line else 'source_vanished'
        elif ('Operation not permitted' in line or 'Permission denied' in line) and line.startswith('rsync:'):
            kind = 'access_denied'
        elif line.startswith('head:') or line.startswith('fd:') or line.startswith('[fd error]'):
            kind = 'materialization'
        elif line.startswith('ERROR:') and 'verification' in line:
            kind = 'verification'
        elif line.startswith('rsync: [receiver]') or line.startswith('rsync: [generator]'):
            kind = 'destination_error'
        elif line.startswith(('rsync:', 'ssh:', 'Connection ', 'rsync error:')):
            kind = 'transfer_error'
        if kind:
            self.counts[kind] += 1
            if kind != 'source_vanished':
                if len(self.samples) < 20:
                    self.samples.append(line)
                # Bound status size even if a destination is being modified underneath us.
                if len(self.issues) < 1000:
                    self.issues.add(line)

    def summary(self, code, elapsed):
        outcome = {0: 'complete', 124: 'timed out', 130: 'interrupted', 143: 'interrupted'}.get(code, 'FAILED')
        parts = [outcome, f'{int(elapsed)}s', f'stage={self.stage}', f'exit={code}']
        if self.rsync_exit is not None:
            parts.append(f'rsync={self.rsync_exit}')
        if self.stats:
            parts.append(self.stats.get('Number of regular files transferred', '?') + ' files')
            parts.append(self.stats.get('Total bytes sent', '?') + ' sent')
        parts.extend(f'{key}={value}' for key, value in sorted(self.counts.items()))
        if self.retries:
            parts.append(f'retries={self.retries}')
        return '; '.join(parts)


def supervise(command, report, timeout):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout
    buffer = b''
    forced_code = None
    kill_deadline = None

    def terminate(code):
        nonlocal forced_code, kill_deadline
        if forced_code is not None:
            return
        forced_code = code
        kill_deadline = time.monotonic() + 5
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

    def stop(signum, frame):
        terminate(128 + signum)

    previous = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        while selector.get_map() or process.poll() is None:
            current = time.monotonic()
            if current >= deadline and forced_code is None:
                print(f'backup-timeout: {timeout}s deadline exceeded', flush=True)
                terminate(124)
            if kill_deadline is not None and current >= kill_deadline:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                kill_deadline = None
            for key, _ in selector.select(0.2):
                data = os.read(key.fd, 65536)
                if not data:
                    selector.unregister(key.fileobj)
                    continue
                buffer += data
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    decoded = line.decode('utf-8', errors='replace')
                    print(decoded, flush=True)
                    report.consume(decoded)
        if buffer:
            decoded = buffer.decode('utf-8', errors='replace')
            print(decoded, flush=True)
            report.consume(decoded)
        code = process.wait()
        return forced_code if forced_code is not None else (code if code >= 0 else 128 - code)
    finally:
        # Unexpected supervisor errors must not leave an unmonitored writer behind.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        selector.close()
        process.stdout.close()
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def write_state(path, state):
    temp = path.with_suffix('.json.tmp')
    temp.write_text(json.dumps(state, indent=2) + '\n')
    temp.replace(path)


def run(log_dir, command, timeout=7200):
    log_dir.mkdir(parents=True, exist_ok=True)
    state_path = log_dir / 'backup-mac-to-thor.status.json'
    with (log_dir / 'backup-mac-to-thor.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('backup-summary: SKIPPED: another backup holds the lock; freshness unchanged', flush=True)
            return 75
        try:
            old = json.loads(state_path.read_text())
        except (FileNotFoundError, ValueError):
            old = {}
        started = now()
        running = dict(old, started_at=started, finished_at=None, stage='running',
                       exit_code=None, summary='running')
        write_state(state_path, running)
        clock = time.monotonic()
        report = Report(lambda stage: write_state(state_path, dict(running, stage=stage, summary=f'running: {stage}')))
        try:
            code = supervise(command, report, timeout)
        except OSError as error:
            print(f'backup-error: {error}', flush=True)
            code = 1
        completed = now()
        summary = report.summary(code, time.monotonic() - clock)
        transfer_completed = report.rsync_exit in (0, 23, 24) and code != 124 and bool(report.stats)
        previous_issues = set(old.get('issues', []))
        if report.issues:
            summary += f'; new_issues={len(report.issues - previous_issues)}'
        state = dict(started_at=started, finished_at=completed, exit_code=code,
                     rsync_exit=report.rsync_exit,
                     last_complete_at=completed if code == 0 else old.get('last_complete_at'),
                     last_transfer_completed_at=completed if transfer_completed else old.get('last_transfer_completed_at'),
                     stage=report.stage, counts=dict(report.counts), stats=report.stats,
                     retries=report.retries, issues=sorted(report.issues),
                     new_issues=sorted(report.issues - previous_issues),
                     resolved_issues=sorted(previous_issues - report.issues) if code == 0 else [],
                     samples=report.samples, summary=summary)
        write_state(state_path, state)
        print('backup-summary: ' + summary, flush=True)
        return code


def configuration():
    # Keep the existing host settings and exclusions in one place. The rsync
    # binary needs its own Full Disk Access grant on this host.
    script = r"""
        printf '%s\0' "$machine_name" "$machine_user"
        for name in (backup-home-exclude-names)
            printf '%s\0' "$name"
        end
        printf '\0'
        for path in (backup-home-exclude-paths)
            printf '%s\0' "$path"
        end
    """
    result = subprocess.run(['/opt/local/bin/fish', '-c', script], check=True,
                            stdout=subprocess.PIPE, timeout=30)
    values = result.stdout.decode().split('\0')
    machine, user = values[:2]
    if not all(re.fullmatch(r'[A-Za-z0-9_.-]+', value) for value in (machine, user)):
        raise ValueError('machine_name and machine_user must be set in ~/locals.fish')
    split = values.index('', 2)
    return machine, user, values[2:split], [p for p in values[split + 1:] if p]


def worker():
    home = str(Path.home())
    machine, user, names, paths = configuration()
    # Read the files rsync actually needs. A separate whole-home fd/head pass
    # can hang before any copying and doesn't use the full rsync filter rules.
    # File Provider supplies cloud content on access; failed reads remain errors.
    print('backup-stage: rsync', flush=True)
    # Preserve the existing mirror scope. Source read errors must inhibit deletion.
    # The Library directory include is required before its subtree includes.
    command = [
        '/opt/local/bin/rsync', '--archive', '--human-readable', '--delete',
        '--delete-excluded', '--stats', '--timeout=300', '--omit-link-times',
        '-e', 'ssh -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=30 -o ServerAliveCountMax=3',
        '--filter', 'protect /.zfs',
    ]
    # Rsync uses the first matching rule. Basenames remain excluded at every
    # depth, including inside the Library trees explicitly included below.
    command += [arg for name in names for arg in ('--exclude', name)]
    command += [
        '--include', '/Library/',
        '--exclude', '/Library/Application?Support/FileProvider',
        '--include', '/Library/Application?Support/***',
        '--include', '/Library/Keychains/***',
        '--include', '/Library/Preferences/***',
        '--exclude', '/Library/*',
    ]
    command += [arg for path in paths for arg in ('--exclude', '/' + path)]
    command += [home + '/', f'thor:/data/tank/mirror/{machine}/{user}']
    for attempt in range(2):
        code = subprocess.call(command)
        print(f'backup-rsync-exit: {code}', flush=True)
        if attempt == 0 and code in (10, 12, 30, 35, 255):
            print(f'backup-retry: transport failure {code}; retrying once in 30s', flush=True)
            time.sleep(30)
        else:
            break
    # Vanished source files are routine on a live home. Other partial transfers fail.
    if code in (0, 24):
        return 0
    return code if code >= 0 else 128 - code


def main():
    os.umask(0o077)
    home = Path.home()
    if sys.argv[1:] == ['--status']:
        try:
            state = json.loads((home / 'logs/backup-mac-to-thor.status.json').read_text())
        except (OSError, ValueError) as error:
            print(f'No readable backup status: {error}', file=sys.stderr)
            return 1
        print(state['summary'])
        for key in ('started_at', 'finished_at', 'last_complete_at', 'last_transfer_completed_at'):
            print(f'{key}: {state.get(key) or "not yet recorded"}')
        print(f'new issues: {len(state.get("new_issues", []))}')
        for sample in state.get('samples', [])[:5]:
            print(sample)
        return 0
    if sys.argv[1:] == ['--worker']:
        try:
            return worker()
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print(f'backup-error: {error}', flush=True)
            return 1
    if sys.argv[1:]:
        print('usage: backup-mac-to-thor.fish [--status]', file=sys.stderr)
        return 2
    return run(home / 'logs', [sys.executable, str(Path(__file__).resolve()), '--worker'])


if __name__ == '__main__':
    sys.exit(main())
