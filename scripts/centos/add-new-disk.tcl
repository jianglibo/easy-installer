mkdir /mount/point
pvcreate /dev/xvdb
vgcreate VolGroup00 /dev/xvdb
lvcreate VolGroup00 -n lvname -l100%FREE
mkfs -t ext4 /dev/VolGroup00/lvname
add to fstab /dev/VolGroup00/lvname /mount/point ext4 defaults 0 0

then:
mount -a
