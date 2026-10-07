# cronwrap

`cronwrap LOG_DIR SNITCH EXECUTABLE [ARGUMENT...]` runs a job, appends its
output to `LOG_DIR/<executable basename>.log`, and reports its exit status and
summary to Dead Man’s Snitch. It executes the supplied argument vector exactly;
it does not parse a shell command string. Quote paths or arguments containing
spaces individually. For example, MacPorts uses:

```sh
/Users/ajm/bin/cronwrap /Users/ajm/logs <snitch-token> /opt/local/bin/port selfupdate
```

Passing `"port selfupdate"` as one argument asks for an executable with a space
in its name and fails. Root’s Brigid crontab owns the MacPorts and crontab-backup
jobs; the user crontab owns the home mirror. `scripts/backup-crontabs.fish`
saves the installed tables under `~/crontabs`; edit the installed table with
`crontab`, not those snapshots. After changing this shared wrapper, check both
users’ tables and migrate their callers before running them.

The wrapper sends `s=<exit status>` and `m=<summary>`. Nonzero status reporting
requires the account’s [DMS Error Notices](https://deadmanssnitch.com/docs/faq)
feature. Jobs emitting `backup-summary:` supply the summary; other jobs report
the executable basename and exit code. A backup overlap (exit 75 with a
`SKIPPED:` summary) sends no check-in. A delivery failure makes a successful job
return nonzero, but never replaces an existing job failure. HTTP errors and
connection/total timeouts are checked, with bounded retries.

Run isolated tests with `/usr/bin/python3 scripts/tests/test_cronwrap.py -v`.
They use fake executables and check-in clients, including a MacPorts cron
invocation, a path and argument containing spaces, job failure, HTTP failure,
and an overlapping backup. The home mirror has its own tests and
[runbook](../scripts/backup-mac-to-thor.README.md).
