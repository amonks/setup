# thor

## Crash dumps

Dumps are compressed on the fly (`dumpon_flags="-z"` in rc.conf) to fit through the 4GB swap partition, then extracted by savecore into `/var/crash`, which is a ZFS dataset (`data/dumps`) with ~7TB of headroom.

`debug.debugger_on_panic=0` in loader.conf so a panic goes straight to dump+reboot instead of dropping to a DDB prompt nobody will see.

## Home directory

`/usr/home/ajm` is a ZFS dataset (`data/tank/home/thor`), not on the root UFS disk. This means it's encrypted along with the rest of `data/tank` and won't be available until the key is loaded and datasets are mounted.

## Shell and PATH

The login shell is fish. When running commands over SSH, fish is the interpreter, which means:

- No `$?` — use `$status` instead, or wrap commands in `sh -c`.
- Wildcards that match nothing are errors, not empty expansions.
- Semicolons chain commands, but `&&` / `||` short-circuit syntax differs from POSIX sh in edge cases.

FreeBSD system binaries (`service`, `pkg`, `jls`, `jexec`, `sysrc`, `freebsd-update`) live in `/usr/sbin/` which is not in fish's default PATH for non-root users. Either use full paths (`/usr/sbin/pkg`) or wrap in `sh -c` (which inherits a POSIX-standard PATH).

## Jails

ezjail is enabled (`ezjail_enable: YES`). Two jails run at boot:

| Jail | IP | Path |
|---|---|---|
| syncer | 10.0.0.10 | /usr/jails/syncer |
| whatboxsyncer | 192.168.1.101 | /usr/jails/whatboxsyncer |

These jails run sendmail, which means cron output and other local mail accumulates in `/var/spool/clientmqueue` inside each jail if delivery isn't configured. Use `jexec <jail> find /var/spool/clientmqueue -type f -delete` to purge (the file count can exceed ARG_MAX, so `rm *` won't work).

## freebsd-update

`freebsd-update` has no `clean` subcommand. Cached patch files live in `/var/db/freebsd-update/files/` and can grow to many GB. After installing pending updates (`freebsd-update install`), it's safe to delete these — they'll be re-fetched on the next `freebsd-update fetch`.

## ZFS encryption key and boot sequence

The encryption key for `data/tank` lives at `/root/zfskey` on the (unencrypted) root disk. The `keylocation` property on `data/tank` points there.

`/etc/rc.local` loads the key and mounts all ZFS datasets at boot:

```sh
#!/bin/sh
/sbin/zfs load-key -a
/sbin/zfs mount -a
```

This runs before cron `@reboot` jobs, so by the time `init.fish` fires, ZFS is already mounted and its ZFS section is a no-op. `init.fish` still handles the whatbox sshfs mount.
