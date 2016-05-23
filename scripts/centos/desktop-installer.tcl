package provide DesktopInstaller 1.0

package require CommonUtil
package require OsUtil

namespace eval ::DesktopInstaller {
}

proc ::DesktopInstaller::install {ymlDict rawParamDict} {
  set appFolderBase [dict get $ymlDict BigestDisk]
  if {! [file exists $appFolderBase]} {
    exec mkdir -p $appFolderBase
  }

  ::CommonUtil::spawnCommand yum groupinstall -y "Development Tools"
  ::CommonUtil::spawnCommand yum -y groups install "GNOME Desktop"
  ::CommonUtil::spawnCommand yum install -y git
  ::CommonUtil::spawnCommand yum install -y gunzip
  ::CommonUtil::spawnCommand ln -sf /lib/systemd/system/runlevel5.target /etc/systemd/system/default.target
}

proc ::DesktopInstaller::installApp {appName ymlDict} {
  set appFolderBase [dict get $ymlDict BigestDisk]
  set appDic [dict get $ymlDict downloads $appName]
  set downFrom [dict get $appDic url]
  set extractor [dict get $appDic extractor]

  set curDir [file join $appFolderBase $appName]

  if {! [file exists $curDir]} {
    exec mkdir -p $curDir
  }

  cd $curDir

  ::CommonUtil::downloadIfNeeded $downFrom $extractor

  set extracted [::CommonUtil::getOnlyFolder $curDir]

  set binFolder [file normalize [file join $extracted [dict get $appDic binFolder]]]

  ::CommonUtil::writeLines [file join /etc/profile.d "${appName}.sh"] [list "export PATH=\$PATH:$binFolder"]
}

proc ::DesktopInstaller::vncserver {ymlDict rawParamDict} {
  ::CommonUtil::spawnCommand yum install -y tigervnc-server
  ::OsUtil::openFirewall tcp 5901
}
