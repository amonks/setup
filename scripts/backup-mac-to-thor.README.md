# Brigid home mirror

The user crontab runs `~/bin/cronwrap ~/logs <snitch-token>
~/scripts/backup-mac-to-thor.fish` daily at 01:11 local time. The `.fish`
filename is retained for the existing cron entry, snitch, and log name; it
is now a POSIX shell launcher for `backup-mac-to-thor-run.py`.

## Read status

```
~/scripts/backup-mac-to-thor.fish --status
```

Detailed state is `~/logs/backup-mac-to-thor.status.json`. Full output remains
in `~/logs/backup-mac-to-thor.fish.log`. Status records the current/last attempt,
last complete backup, last finished transfer (which may be partial), raw rsync
results, counts, bounded error samples, and new error signatures.
Freshness starts being recorded by this implementation; an absent complete
backup timestamp means none has been observed by it.

The snitch receives the exit status and a concise summary via DMS `s=` and
`m=`. Error Notices require a supporting DMS plan. `cronwrap` preserves the
job's exit status; a failed check-in also makes an otherwise successful wrapper
return nonzero. It checks HTTP failures and bounds reporting retries. Local
backup state describes the backup itself, independently of check-in delivery.

## Execution and access

The supervisor holds an advisory OS lock at `~/logs/backup-mac-to-thor.lock`
throughout the worker. Locks release automatically when the supervisor exits;
the persistent lock file is normal and should not be removed. A second run
exits 75 without starting a worker or checking in the snitch. The entire worker
process group has a two-hour deadline, including cloud-file reads;
it gets SIGTERM then SIGKILL after five seconds. A timeout returns 124.

SSH is noninteractive, with a 15-second connect timeout and 30-second
keepalives (three misses). Rsync has a 300-second I/O timeout. Transport errors
10/12/30/35/255 get one retry after 30 seconds within the overall deadline.

macOS Full Disk Access depends on the execution context and actual binary.
On this host cron and `/usr/bin/rsync` have Full Disk Access, and the job uses
`/opt/local/bin/rsync`, whose separate grant was enabled on 2026-10-04.
A cron probe on 2026-10-03 confirmed that direct Python could read protected
paths, but Fish and the MacPorts rsync could not; moving rsync out of Fish alone
was insufficient. Grant access to the installed MacPorts rsync rather than
assuming the system rsync's existing grant covers it. No TCC database edits
are part of this implementation. An interactive test can differ from cron.

Fish continues to supply machine_name, machine_user and backup-home-exclude-*. Python supervises these child
processes and invokes rsync directly. The wrapper no longer requires Fish as
its top-level interpreter.

## Coverage and outcomes

The mirror covers home plus Library Application Support, Keychains and
Preferences; FileProvider and other Library trees remain excluded. Exclusions
come from the Fish helpers. Basename exclusions apply at every depth, including
inside the selected Library trees; those exclusions precede recursive includes. `--omit-link-times` avoids stale-owner symlink mtime errors. `/.zfs`
is protected. `--delete` and `--delete-excluded` make this a mirror; changing
an exclusion can delete matching files from the live destination. ZFS snapshot
history is separate.

Source I/O errors now inhibit deletion: do not add `--ignore-errors` back.
The whole-home fd/head pre-read was removed after it consumed the complete
2026-10-04 run without reaching rsync. Rsync opens the included files it actually
needs; File Provider fetches dataless content on access. Read errors remain
failures and inhibit deletion. The independent materialize-icloud helper is
still available, but it is not a prerequisite for this backup.

Exit 24 (vanished source files on a live filesystem) is accepted, with counts kept in status. Exit 23 is never blanket-accepted:
new access failures, destination problems, or read errors must remain visible.
Source churn and disappearing destination files are classified separately.

This is a file mirror, not an application-consistent backup of live SQLite
databases. Database recovery needs independently verified database backups.
Time Machine, Thor's ZFS snapshot schedule, and offsite replication are separate
systems and are not certified by this snitch. A successful transfer does not
claim they have completed or that a restore has been tested.

## Regression checks

```
/usr/bin/python3 -m unittest discover -s ~/scripts/tests -p 'test_*py' -v
```

These tests use temporary files and fake workers/check-in clients. They never
contact Thor or the production snitch. Pre-change script and crontab copies are
in `~/logs/backup-maintenance-2026-10-03/`.
