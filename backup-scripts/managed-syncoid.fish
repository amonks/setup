#!/usr/bin/env fish

if test (whoami) != "root"
    echo must be root
    exit 1
end

echo managing syncoid command:
echo syncoid $argv
echo

while true
# run the backup
    rm /usr/home/ajm/.backup.lock
    syncoid $argv &
    set backup_pid $last_pid
    set backup_status ""
    function done --on-process-exit $backup_pid
        echo \n"[$backup_pid] process exit: $argv[3]"
        set backup_status "$argv[3]"
    end
    echo \n"[$backup_pid] started"

# - if it fails, wait 30s and retry; or,
# - if 1800s passes, stop waiting and continue
    set time_to_wait 1800
    while test "$time_to_wait" -gt 0
        echo \n"[$backup_pid] waiting for run: $time_to_wait"

        sleep 5
        set time_to_wait (math "$time_to_wait" - 5)

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
        echo \n"[$backup_pid] retrying"
        continue
    end

# kill the backup
    echo \n"[$backup_pid] timed out: killing"
    pkill -9 -P $backup_pid

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
