echo "not a real script"
exit 0

# mypool/tank is encrypted
# mypool/data is not
# disk isn't big enough to hold two copies of mypool/data
# goal: encrypt in-place; one dataset at a time
# this will take forever -- also have to back up each one 


# TODO
#
# [x] create pool
#
# mirror/github:
#	  [x] disable ingress
#     [x] sync into encrypted place
#     [x] enable ingress
#     [x] double-check sync
#     [x] back up
#     [x] delete on backup
#     [ ] delete locally
#
# mirror/mail:
#	  [x] disable ingress
#     [x] sync into encrypted place
#     [x] enable ingress
#     [x] back up
#     [x] delete on backup
#     [x] delete locally
#
# mirror/sambox/joychen:
#	  [x] disable ingress
#     [ ] sync into encrypted place
#     [ ] enable ingress
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
	sudo ./backup-scripts/managed-syncoid.fish --no-sync-snap --no-rollback \
		"mypool/data/$dataset" "mypool/tank/$dataset"

	# swap destination of whatever backs up to this; re-enable
	
	# back up to rsync
	syncoid --sendoptions="w" "mypool/tank/$dataset" "rsync:data1/thor/tank/$dataset"

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


