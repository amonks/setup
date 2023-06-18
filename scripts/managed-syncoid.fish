#!/usr/bin/env fish

argparse 'k/kill-every-n-hours=' 'd/dry-run' 'r/recursive' -- $argv

if test -z "$_flag_dry_run"
    if test (whoami) != "root"
        echo error: must be root.
        exit 1
    end
end

set target "/"$argv
if test "$target" = "/"
    echo "no target specified. sync everything?"
    read -P 'OK? '
    set target ""
end

set syncoid_args --sshkey /usr/home/ajm/.ssh/id_ed25519 \
    --recursive \
    --no-commands \
    --no-sync-snap \
    --sendoptions='w'

if test -n "$_flag_recursive"
    set -a syncoid_args --recursive
end

set -a syncoid_args \
    mypool/tank$target \
    root@57269.zfs.rsync.net:data1/thor/tank$target

echo managing syncoid command:
echo syncoid $syncoid_args
read -P 'continue? '
echo

while true
    # run the backup
    if test -z "$_flag_dry_run"
        touch /usr/home/ajm/.backup.lock
    end
    set backup_pid "dry-run"
    set backup_status ""

    function log
        if test "$argv[1]" = "-n"
            echo
            set argv $argv[2..]
        end
        echo [$backup_pid] (date): $argv
    end

    if test -z "$_flag_dry_run"
        syncoid $syncoid_args &
        set backup_pid $last_pid

        function done --on-process-exit $backup_pid
            log process exit: $argv[3]
            set backup_status "$argv[3]"
        end
    end

    log started

    # - if it fails, wait 30s and retry; or,
    # - if 3600s passes, stop it and retry
    set time_until_kill "forever"
    if test -n "$_flag_kill_every_n_hours"
        echo killing every $_flag_kill_every_n_hours hours
        set time_until_kill (math "$_flag_kill_every_n_hours" '*' 3600)
    end

    echo time_until_kill: $time_until_kill

    while test "$time_until_kill" = "forever" || \
          test "$time_until_kill" -gt 0
        log -n waiting for run: $time_until_kill

        sleep 5
        if test "$time_until_kill" != "forever"
            set time_until_kill (math "$time_until_kill" - 5)
        end

        if test -n "$backup_status"
            if test 0 -eq "$backup_status"
                echo \n"[$backup_pid] done"
                exit 0
            end
            echo \n"[$backup_pid] failed: $backup_status"
            break
        end
    end

    # if it died naturally, we can retry
    if test -n "$backup_status"
        log retrying

        continue
    end

    # kill the backup
    if test -n "$_flag_dry_run"
        log would kill
        set backup_status 0
    else
        log timed out: killing
        pkill -9 -P $backup_pid
        # wait for children to die also?
    end

    # wait for death
    set time_waited 0
    while true
        echo \n"[$backup_pid] waiting for death: $time_waited"

        # dead; stop waiting and continue
        if test -n "$backup_status"
            echo \n"[$backup_pid] dead: $backup_status"
            set -e backup_status
            break
        end

        # keep waiting
        set time_waited (math "$time_waited" + 5)
        sleep 5
    end

# retry
    sleep 5
    echo \n"[$backup_pid] retrying"
    continue
end
