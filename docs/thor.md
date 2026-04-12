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

## ZFS pool topology

The `data` pool is two raidz2 vdevs across two different controller paths:

| Vdev | Drives | Controller | Device names |
|---|---|---|---|
| raidz2-0 | 8x Samsung 870 EVO 4TB | Avago SAS3008 HBA (`mpr` driver) via SuperMicro SC216-P JBOD shelf | `da0`–`da7` |
| raidz2-1 | 8x Samsung 870 EVO 4TB | Onboard AHCI (`ahcich`, `ahci1`) | `ada1`–`ada8` |

All drives are SSDs despite the JBOD shelf. `ada0` is a SuperMicro SSD SOB20R boot drive, not part of the pool.

There is no SLOG and no L2ARC. Sync writes go directly to the main pool vdevs. The `logbias` is `latency` (default). If sync write latency becomes a problem (databases, NFS sync), a SLOG would help — currently raidz2-1 shows occasional sync write stalls in the 500ms range, likely related to AHCI flush behavior and lack of TRIM (see below).

`ashift` is 12 (4K sectors, set at pool creation).

## TRIM

`autotrim` is **off**. Both controller paths support TRIM (`CANDELETE` flag is set on all devices). Since this is an all-SSD pool, TRIM matters for sustained write performance and drive longevity. Either enable autotrim (`zpool set autotrim=on data`) or schedule periodic `zpool trim data`.

## Vdev capacity imbalance

The two vdevs do not fill evenly. As of April 2026, raidz2-0 was at 93% (32% fragmentation) while raidz2-1 was at 69% (25% fragmentation). ZFS write performance degrades above ~80% per-vdev capacity.

ZFS has no native rebalance command. To rebalance, rewrite data so the allocator places new blocks on the emptier vdev. The allocator weights by free space, so new writes will strongly prefer whichever vdev has more room.

For datasets that fit in available free space, use the send/recv swap procedure below. For datasets too large to duplicate, rewrite files in place (`cp file file.tmp && mv file.tmp file`), which only needs free space for one file at a time but doesn't free old blocks held by snapshots.

### Send/recv rebalance procedure

The pool uses encrypted datasets (`aes-256-gcm`, key at `/root/zfskey`, encryption root is `data/tank`). Raw send (`-w`) is required, which causes the received dataset to become its own encryption root. The procedure accounts for this.

**Stop if anything is unexpected.** If sizes don't match, if an unmount fails, if a rename reports busy — do not force through it. Investigate until you understand what's happening before continuing. The old copy should not be destroyed until everything is verified.

**Send throughput is ~500-600 MB/s** on this hardware. A 334 GB dataset takes ~10 minutes; multi-TB datasets take hours. If running the send via Claude Code, the Bash tool has a 10-minute timeout maximum — for datasets over ~300 GB, run the send in a tmux/screen session on thor directly, or background it. A killed `zfs send | zfs recv` leaves a partial dataset that must be destroyed and retried.

```sh
# 1. Record baseline (save these numbers for comparison)
zfs list -o name,used,refer data/tank/<ds>
zfs list -t snapshot -r data/tank/<ds> | wc -l    # snapshot count

# 2. Snapshot and send (slow part — samba stays up)
zfs snapshot data/tank/<ds>@rebalance
zfs send -Rw data/tank/<ds>@rebalance | zfs recv -o mountpoint=none data/tank/<ds>-rebal

# 3. Verify copy matches baseline
#    Compare used, refer, and snapshot count against step 1.
#    If anything doesn't match, STOP and investigate.
zfs list -o name,used,refer data/tank/<ds> data/tank/<ds>-rebal
# compare snapshot counts

# --- OPERATOR: identify and stop all writers to this dataset ---
#
# Ask the operator what services or processes write to this dataset.
# Check with: fstat -m /data/tank/<ds>
# The operator must stop those services before continuing.
# Samba alone is not sufficient — databases, litestream, cron jobs,
# etc. may also hold the dataset open.

# 4. Stop samba and any other writers identified above
service samba_server stop

# 5. Swap
#    If any rename fails with "busy", STOP. Do not force-unmount.
#    Re-check fstat, re-check with the operator. Something is still
#    writing that we haven't accounted for.
zfs rename data/tank/<ds> data/tank/<ds>-old
zfs rename data/tank/<ds>-rebal data/tank/<ds>
zfs inherit mountpoint data/tank/<ds>

# 6. Fix encryption (raw send breaks inheritance)
zfs set keylocation=file:///root/zfskey data/tank/<ds>
zfs load-key data/tank/<ds>
zfs mount data/tank/<ds>
zfs change-key -i data/tank/<ds>

# 7. Restart samba and any other services stopped in step 4
service samba_server start

# 8. Verify data is accessible and sizes match baseline
#    Do NOT destroy the old copy until this is confirmed.
zfs list -o name,used,refer data/tank/<ds>
ls /data/tank/<ds>/

# 9. Destroy old copy
zfs destroy -r data/tank/<ds>-old
```

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

This runs before cron `@reboot` jobs, so by the time `init.fish` fires, ZFS is already mounted and its ZFS section is a no-op. `init.fish` still handles the whatbox sshfs mount.
