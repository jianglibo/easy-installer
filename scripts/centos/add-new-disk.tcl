package provide AddNewDisk 1.0
package require CommonUtil

namespace eval ::AddNewDisk {
}

proc ::AddNewDisk::add {ymlDict rawParamDict} {
  if {! [dict exists $rawParamDict disk]} {
    puts "disk parameter are mandatory, for example --disk=/dev/sdb"
    ::CommonUtil::endEasyInstall
  }
  set cfgDic [dict get $ymlDict AddNewDisk]
  set mpoint [dict get $cfgDic MountPoint]
  set disk [dict get $rawParamDict disk]
  set vg [dict get $cfgDic VolumeGroup]
  set vl [dict get $cfgDic VolumeName]
  set fs [dict get $cfgDic Fs]
  set disklines [split [exec fdisk -l | grep -Ei {^Disk\s+/dev/\w+:}] \n]
  set foundpv 0
  foreach dl $disklines {
    if {[string match "*${disk}:*" $dl]} {
      set foundpv 1
    }
  }
  if {! $foundpv} {
    puts "${disk} not found."
    ::CommonUtil::endEasyInstall
  }

  if {! [file exists $mpoint]} {
    exec mkdir -p $mpoint
  }

  ::CommonUtil::spawnCommand pvcreate $disk
  ::CommonUtil::spawnCommand vgcreate $vg $disk
  ::CommonUtil::spawnCommand lvcreate $vg -n $vl -l100%FREE

  set fullLvName /dev/$vg/$vl
  ::CommonUtil::spawnCommand mkfs -t $fs $fullLvName

  ::CommonUtil::backupOrigin /etc/fstab
  set lines [::CommonUtil::readLines /etc/fstab]

  set founded 0

  foreach line $lines {
    if {[string first $fullLvName $line] == 0} {
      set founded 1
      break;
    }
  }

  if {! $founded} {
    if {[catch {open /etc/fstab w} fid o]} {
      puts $fid
      :CommonUtil::endEasyInstall
    } else {
      foreach line $lines {
        puts $fid $line
      }
      puts $fid "$fullLvName $mpoint ext4 defaults 0 0"
      close $fid
    }
  }
  exec mount -a
}

#mkdir /mount/point
#pvcreate /dev/xvdb  #physical volume
#vgcreate VolGroup00 /dev/xvdb #volume group create
#lvcreate VolGroup00 -n lvname -l100%FREE #logical volume create -l50%VG, 50pecent of available vg space. -l50%FREE, the 50 percent of remain vg space.
#mkfs -t ext4 /dev/VolGroup00/lvname
#add to fstab /dev/VolGroup00/lvname /mount/point ext4 defaults 0 0

#then:
#mount -a
