#!/usr/bin/env fish

# mypool/tank is encrypted
# mypool/data is not
# disk isn't big enough to hold two copies of mypool/data
# goal: encrypt in-place; one dataset at a time
# this will take forever -- also have to back up each one 

function encrypt-locally --argument-names dataset
    if test -z "$dataset"
        echo "dataset not provided for local encrypt"
        return 1
    end

    echo
    echo "encrypting local $dataset"
    echo sudo syncoid \
        --no-commands --no-sync-snap  \
        "mypool/data/$dataset" "mypool/tank/$dataset"

    if test "$dry_run" = false
        sudo syncoid \
            --no-commands --no-sync-snap  \
            "mypool/data/$dataset" "mypool/tank/$dataset"
        return $status
    end

    return 0
end

function backup-encrypted --argument-names dataset
    if test -z "$dataset"
        echo "dataset not provided for encrypted backup"
        return 1
    end

    echo
    echo "backing-up encrypted $dataset"
    echo sudo syncoid \
        --sshkey /home/ajm/.ssh/id_ed25519 \
        --no-commands --no-sync-snap  --sendoptions="w" \
        "mypool/tank/$dataset" "root@57269.zfs.rsync.net:data1/thor/tank/$dataset"

    if test "$dry_run" = false
        sudo syncoid \
            --sshkey /home/ajm/.ssh/id_ed25519 \
            --no-commands --no-sync-snap  --sendoptions="w" \
            "mypool/tank/$dataset" "root@57269.zfs.rsync.net:data1/thor/tank/$dataset"
        return $status
    end

    return 0
end

function destroy-unencrypted-locally --argument-names dataset
    if test -z "$dataset"
        echo "dataset not provided for local unencrypted destruction"
        return 1
    end

    echo
    echo "destroying local unencrypted $dataset"
    echo zfs destroy -r "mypool/data/$dataset"

    if test "$dry_run" = false
        zfs destroy -r "mypool/data/$dataset"
        return $status
    end

    return 0
end

function destroy-unencrypted-remotely --argument-names dataset
    if test -z "$dataset"
        echo "dataset not provided for remote unencrypted destruction"
        return 1
    end

    echo
    echo "destroying remote unencrypted $dataset"
    echo ssh -i /home/ajm/.ssh/id_ed25519 root@57269.zfs.rsync.net zfs destroy -r "data1/thor/data/$dataset"

    if test "$dry_run" = false
        ssh -i /home/ajm/.ssh/id_ed25519 root@57269.zfs.rsync.net zfs destroy -r "data1/thor/data/$dataset"
        return $status
    end

    return 0
end

set dry_run false

encrypt-locally mirror/whatbox
# and exit 0
# and destroy-unencrypted-locally mirror/whatbox






# while true
#     if test "$status" -eq 0
#         exit 0
#     end
#     sleep 60Ss
# end

# destroy-unencrypted-locally $dataset

exit $status

# TODO
#
# [x] create pool
#
# mirror/github:
#      [x] disable ingress
#     [x] sync into encrypted place
#     [x] enable ingress
#     [x] double-check sync
#     [x] back up
#     [x] delete on backup
#     [x] delete locally
#
# mirror/mail:
#      [x] disable ingress
#     [x] sync into encrypted place
#     [x] enable ingress
#     [x] back up
#     [x] delete on backup
#     [x] delete locally
#
# mirror/sambox/joychen:
#      [x] disable ingress
#     [x] sync into encrypted place
#     [x] enable ingress
#     [ ] back up
#     [ ] delete on backup
#     [ ] delete locally

# create the pool
sudo zfs create -o encryption=on -o compression=on -o atime=off \
    -o keylocation=file:///usr/home/ajm/zfskey -o keyformat=raw \
    mypool/tank


# for each dataset
    set dataset "mirror/github"

    # disable whatever backs up to this

    # need to explicitly create parent first?
        syncoid "mypool/data/PARENT" "mypool/tank/PARENT"

    # encrypt the data
    sudo ./scripts/managed-syncoid.fish \
        --no-commands --no-sync-snap \
        "mypool/data/$dataset" "mypool/tank/$dataset"

    # swap destination of whatever backs up to this; re-enable
    
    # back up to rsync
    sudo syncoid \
        --sshkey /home/ajm/.ssh/id_ed25519 \
        --no-commands --no-sync-snap --sendoptions="w" \
        "mypool/tank/$dataset" "root@57269.zfs.rsync.net:data1/thor/tank/$dataset"

    # check that the backup worked
    scp ~/zfskey rsync:/root/key
    ssh rsync
        zfs list -o name | grep tank | xargs -n1 zfs set keylocation=file:///root/key
        zfs load-key data1/thor/tank/$dataset
        zfs list -o name,encryption,keystatus,keylocation,keyformat
        zfs mount data1/thor/tank/$dataset
        ls /mnt/data1/thor/tank/$dataset

    # delete old data
    ssh rsync zfs destroy -r "data1/thor/data/$dataset"
    zfs destroy -r "mypool/data/$dataset"

    # TODO seems like rsync keeps -all- snapshots; not just the n most recent
    # eg it has dailies going back forever


