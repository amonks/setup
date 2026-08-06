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

## Package repository and minor-version upgrades

Thor tracks the `latest` pkg branch (`pkg+https://pkg.FreeBSD.org/${ABI}/latest`). When a new FreeBSD minor release ships, the `latest` build cluster switches to building on it, and the nightly root `pkg update` cron job (03:15, snitch-backed, logs to `~/logs/pkg.log`) starts failing with "repository contains packages for wrong OS version" until the OS is upgraded. The nightly `freebsd-update cron` job only fetches security patches for the installed release and never performs minor upgrades, so this doesn't self-heal — it needs a manual `freebsd-update -r X.Y-RELEASE upgrade` / `install` / reboot / `install` / `pkg upgrade` cycle. This happened at 14.1→14.2 (April 2025) and 14.3→14.4 (July 2026).

During the upgrade's config merge, locally modified files (e.g. `sshd_config`, which sets `KbdInteractiveAuthentication no`) can conflict; `freebsd-update` prompts on /dev/tty, so it hangs if run without one.

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

`autotrim` is **on** (set locally on the `data` pool: `zpool get autotrim data`).
Both controller paths support TRIM (`CANDELETE` is set on all devices), so ZFS
issues deletes to the SSDs as blocks are freed rather than relying on a periodic
`zpool trim`.

Note the drive quirk this interacts with: the Samsung 870 EVO 4TB members probe
with `quirks=0x3<4K,NCQ_TRIM_BROKEN>`, so FreeBSD's ada driver refuses *queued*
(NCQ) TRIM on them and falls back to non-queued `DSM TRIM`. `autotrim=on` is safe
with that fallback; the quirk only disables the NCQ form, not TRIM itself.

## ZFS event capture and fault daemon

Two things exist so that a ZFS incident is diagnosable after the fact. Both were
added after a July 2026 outage in which the `data` pool suspended
(`failmode=wait`, so the box stayed pingable but every access to the pool hung
forever) with **no** device-, controller-, or PCIe-level error logged anywhere —
and by the time it was investigated the volatile in-kernel event ring had been
cleared by the reboot, so there was no way to tell which vdev dropped.

**`zfsd` (native FreeBSD ZFS fault daemon)** is enabled (`zfsd_enable=YES` in
rc.conf; `service zfsd status`). It consumes `devctl`/zevents in real time, logs
vdev faults to syslog, and takes corrective action (degrade/retire, activate a
spare). It had been *off* — a 16-drive pool was running with no fault daemon,
which is part of why the outage produced so little device-level logging.

**A `zpool events` follower** persists the full, verbose event stream to disk so
it survives both the reboot-clears-the-ring problem and a pool suspension:

- Script: `/usr/local/sbin/zpool-events-logger.sh` — `exec zpool events -v -f >> /var/log/zpool-events.log`.
- Started at boot from **root's** crontab: `@reboot /usr/sbin/daemon -f -r -P /var/run/zpool-events-logger.pid /usr/local/sbin/zpool-events-logger.sh` (`daemon -r` restarts it if it dies).
- The log lives on `/var/log`, which is on the **UFS root** (`ada0p2`), not on
  the `data` pool. That is deliberate: when the pool is I/O-suspended, writes to
  the pool block, but writes to `/var/log` keep working — so the follower keeps
  recording the very events (io/probe failures, vdev state changes, with GUIDs
  and paths) that explain a suspension, right up to and through it.
- Rotated by `newsyslog` via `/etc/newsyslog.conf.d/zpool-events.conf`
  (keep 7, rotate at 1000 KB, compress).

After an incident, read `/var/log/zpool-events.log` (and its `.bz2` rotations)
for the vdev-level detail; `zpool events -v` alone only shows what is left in the
ring since the last boot.

## JBOD SAS link and pool-suspension incidents

The `raidz2-0` half of the `data` pool lives in the SC216 JBOD shelf, reached
from the Avago SAS3008 HBA (`mpr0`) over two external x4 SAS cables that form
one x8 wide port to the shelf's expander. On the expander, phys 20–27 are the
cable uplinks and phys 32–39 are the eight drives (`smp_discover /dev/ses2`).
The shelf has a single PSU installed; `sesutil map -u /dev/ses2` always shows a
second Power Supply element as **Critical (AC fail + DC fail)** — that is the
empty bay, not a fault.

If the SAS link to the shelf bounces even for a couple of seconds, all eight
`da` drives plus the `ses2` enclosure processor detach at once, ZFS marks the
whole vdev REMOVED, and the pool **suspends** (`failmode=wait`) — and it stays
suspended even after the devices re-attach seconds later. This happened
2026-07-31 (a ~2-second bounce at 01:46; cause never proven — cables were
reseated and found fine, the server BMC logged no power event, and nothing was
scheduled then) and is the likely shape of the undiagnosed July 2026 outage.

**Recognizing it**: the box stays pingable and `ssh thor <command>` works
(binaries and cached reads don't touch the pool), but interactive logins hang
forever — fish startup runs `atuin init fish`, which blocks in `D` state on the
suspended pool (home is on `data/tank`). `w` fills with wedged `atuin init
fish` sessions. Confirm with `zpool status` (works while suspended).

**Recovery**: check the drives re-enumerated (`camcontrol devlist`, labels in
`/dev/gpt/`), then `sudo zpool clear data`. Queued writes flush, wedged
processes resume, and transient "data errors" clear; nothing is lost (CoW).
Don't power off while suspended — shutdown hangs syncing the pool and drops
the queued writes; clear first. Scrub afterward to verify.

**Link-health monitoring**: `smp_utils` is installed. Per-phy error counters:
`sudo smp_rep_phy_err_log -p <N> /dev/ses2`. Counters zero at shelf power-on;
a baseline from 2026-07-31 is at `~/logs/sas-phy-err-baseline-2026-07-31.txt`
(healthy = a handful of invalid dwords and one loss-of-sync per uplink phy
from link training, zeros on drive phys). Growing counts on phys 20–27
localize a marginal cable/lane. If a bounce recurs: swap the SAS cables, then
suspect the shelf expander/backplane or its single PSU. The HBA firmware is
16.00.10.00 (latest for SAS3008 is 16.00.12.00) — a candidate update at a
planned downtime.

The server's BMC event log is readable with `sudo kldload ipmi && sudo
ipmitool sel elist` (historical "AC lost + chassis intrusion" pairs are past
maintenance sessions, not incidents).

## Syslog routing for supervised apps

The monks_* apps run under `daemon(8)` (see the host-deploy spec in the monks.co
repo), whose `-S` sends each app's stdout/stderr to syslog on the `daemon`
facility. The base
`/etc/syslog.conf` sends `daemon.info` to `/var/log/daemon.log`, but its
`*.notice` catch-all *also* matched the daemon facility, so every app line was
written **twice** — once to `daemon.log` and once to `/var/log/messages`.

That second copy is what made the July 2026 outage undiagnosable: chatty app
output (made far worse by `run` pretty-printing each JSON log event into ~15
colored lines — since fixed in `cmd/run`) rotated `/var/log/messages` every 1–2
hours, so the kernel's ZFS pool-suspension records had aged out before anyone
looked.

The messages selector now carries `daemon.none`:

```
*.notice;authpriv.none;kern.debug;lpr.info;mail.crit;news.err;daemon.none	/var/log/messages
```

so app output goes only to `/var/log/daemon.log`, while `/var/log/messages`
keeps kernel/ZFS records (`kern.*`) uncrowded. Backup of the pre-change file is
at `/etc/syslog.conf.bak`. To read an app: `grep monks_<app> /var/log/daemon.log`
(and `bzgrep` its `.bz2` rotations); `messages` is for kernel/system events.

## Snapshot retention policy

Automated snapshots are taken daily, monthly, and yearly by `backupd` (cmd/backupd in the monks.co repo; config in `/usr/local/etc/backupd.toml`), which also replicates them to rsync.net (`root@de1424b.rsync.net:data1/thor/tank`) and prunes both sides hourly. The oldest snapshot for each dataset is retained indefinitely as a historical baseline — this is intentional and these should not be destroyed even if they hold significant unique space.

Exception: `data/tank/tm/*` (Time Machine sparsebundles) uses a backupd override — `keep_baseline = false` with `daily = 1` on both sides. Time Machine keeps its own history inside the image, so ZFS snapshot history there is versioning-of-versions that pins ~20-25 GB of band churn per day. Only the latest daily and the shared sync-point snapshot are retained; expect to see just one or two snapshots on these datasets.

### backupd operation

The daemon is supervised by `/usr/local/etc/rc.d/backupd`, which runs `/home/ajm/go/bin/backupd` (rebuild with `go install .` from `cmd/backupd` in the repo checkout at `~/git/amonks/monks.co`) under `daemon -r` as root. Its dashboard and control API are bound to the tailnet only (`listen = "100.93.23.97:8888"` in the config) because the API is unauthenticated and can edit the config and pause backups — do not widen this to `0.0.0.0`.

Pause state lives in the config file itself (`paused = true` at top level, or per override subtree), toggled by the dashboard/CLI or by hand. While paused, backupd still refreshes state and shows planned actions but executes nothing, and it withholds the Dead Man's Snitch ping, so a long pause will (intentionally) trip the snitch.

**Current state (July 2026): backupd is fully paused via the config and the rc unit is stopped.** Snapshots, replication, and pruning are not running; the snitch for `97cb3d76e0` will fire until it's resumed. To bring it back: `sudo service backupd start` (or `onestart` if `backupd_enable` isn't set in rc.conf), then remove `paused = true` from the config or hit Resume in the dashboard at http://100.93.23.97:8888. The pre-dashboard config is backed up at `/usr/local/etc/backupd.toml.bak-2026-07-27`.

## Time Machine shares

`brigidtm` and `lughtm` in smb4.conf serve `data/tank/tm/*` with `fruit:time machine = yes` and `fruit:time machine max size = 2T`. The max size is what caps backup growth: macOS reads it as the destination volume size and thins old backups to stay under it. Without it, the sparsebundle grows unbounded (brigid's was created with a 16 TB virtual APFS container and reached 3.2 TB before the quota was added in July 2026). Note that Time Machine refuses to run at all if the sparsebundle is already *over* the advertised quota — recovery requires manually deleting old backups (`tmutil delete -d <mount> -t <timestamp>` against the attached image) and compacting with `hdiutil compact`.

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
