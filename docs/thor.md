# thor

The purpose of this file is to document things about the machine Thor's configuration that are not standard or not obvious, to help operators understand what there is. Configuration, workloads it's running, hardware, things like that. It is not a lab notebook, a changelog, or a specification.

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

FreeBSD system binaries (`service`, `pkg`, `sysrc`, `freebsd-update`) live in `/usr/sbin/`, which is not in fish's default PATH for non-root users. For direct invocations, use full paths (`/usr/sbin/pkg`) or wrap in `sh -c` (which inherits a POSIX-standard PATH). Sudo has `/usr/sbin` in its `secure_path` (via `/usr/local/etc/sudoers.d/secure_path`), so `sudo pkg`, `sudo chown` etc. resolve bare.

## Frozen S3 mirror

`data/tank/mirror/s3/ajm-2021` is a 423 GB ZFS dataset holding a snapshot of ~70 S3 buckets mirrored in January 2021, with one bucket refreshed October 2023. Most of the source buckets no longer exist in S3 (gifbooth, radblock, flynn, beanstalk-era artifacts).

## ZFS pool topology

The `data` pool is two raidz2 vdevs across two different controller paths:

| Vdev | Drives | Controller | Device names |
|---|---|---|---|
| raidz2-0 | 8x Samsung 870 EVO 4TB | Avago SAS3008 HBA (`mpr` driver) via SuperMicro SC216-P JBOD shelf | `da0`–`da7` |
| raidz2-1 | 8x Samsung 870 EVO 4TB | Onboard AHCI (`ahcich`, `ahci1`) | `ada1`–`ada8` |

All drives are SSDs despite the JBOD shelf. `ada0` is a SuperMicro SSD SOB20R boot drive, not part of the pool.

There is no SLOG and no L2ARC. Sync writes go directly to the main pool vdevs. The `logbias` is `latency` (default).

`ashift` is 12 (4K sectors, set at pool creation).

## TRIM

`autotrim` is **off**. Both controller paths support TRIM (`CANDELETE` flag is set on all devices).

## Snapshot retention policy

Automated snapshots are taken daily, weekly, monthly, and yearly. The oldest snapshot for each dataset is retained indefinitely as a historical baseline — this is intentional and these should not be destroyed even if they hold significant unique space.

## ZFS ARC minimum

`vfs.zfs.arc_min` is set to 64GB (68719476736 bytes) in `/boot/loader.conf`.

Without this, FreeBSD's page daemon suppresses ARC growth whenever free memory dips below `v_free_target` (~2.8GB). It sets the `arc_no_grow` flag and sends prune requests, which prevents the ARC from using reclaimed Inactive pages even when the system has 100+ GB of reclaimable memory. The ARC gets stuck at ~9.5GB on a 128GB machine.

The practical effect is that ZFS metadata for working directories gets evicted between uses. Operations that stat many files (jj, git) go from ~0.2s with warm ARC to ~8s with cold ARC, because each stat requires multiple ARC lookups that miss and hit disk.

The 64GB floor leaves 64GB for processes, UFS page cache, and kernel. Actual process RSS on this machine is typically ~1GB.

## ZFS encryption key and boot sequence

The encryption key for `data/tank` lives at `/root/zfskey` on the (unencrypted) root disk. The `keylocation` property on `data/tank` points there.

`/etc/rc.local` loads the key and mounts all ZFS datasets at boot:

```sh
#!/bin/sh
/sbin/zfs load-key -a
/sbin/zfs mount -a
```

This runs before cron `@reboot` jobs, so by the time `init.fish` fires, ZFS is already mounted and its ZFS section is a no-op. `init.fish` handles the whatbox sshfs mount.
