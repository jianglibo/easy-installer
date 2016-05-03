mkdir /mount/point
pvcreate /dev/xvdb  #physical volume
vgcreate VolGroup00 /dev/xvdb #volume group create
lvcreate VolGroup00 -n lvname -l100%FREE #logical volume create -l50%VG, 50pecent of available vg space. -l50%FREE, the 50 percent of remain vg space.
mkfs -t ext4 /dev/VolGroup00/lvname
add to fstab /dev/VolGroup00/lvname /mount/point ext4 defaults 0 0

then:
mount -a
