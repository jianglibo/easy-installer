package provide CheInstaller 1.0
package require CommonUtil
package require OsUtil

namespace eval CheInstaller {
  variable dockRepo /etc/yum.repos.d/docker.repo
  variable dstFolder /opt/che
  variable dockRepoContent {
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
}
  if {! [file exists $dstFolder]} {
    exec mkdir -p $dstFolder
  }
}

proc ::CheInstaller::install {ymlDict rawParamDict} {
  variable dstFolder
  createDockRepo
  ::CommonUtil::spawnCommand yum install -y docker-engine
  ::CommonUtil::spawnCommand systemctl enable docker
  ::CommonUtil::spawnCommand systemctl start docker
  setupUser

  set srcUrl [dict get $ymlDict DownFrom]
  cd $dstFolder

  set tarFile [lindex [split $srcUrl /] end]

  if {! [file exists $tarFile]} {
    ::CommonUtil::spawnCommand curl -OL $srcUrl
  }

  if {! [file exists [getAppFolder]]} {
    ::CommonUtil::spawnCommand tar -xf $tarFile
  }

  exec chown -R che $dstFolder
  ::OsUtil::openFirewall tcp 8080 32768-65535
}

proc ::CheInstaller::getAppFolder {} {
  variable dstFolder
  return [glob -nocomplain -directory $dstFolder -type d *]
}

proc ::CheInstaller::setupUser {} {
  catch {exec groupadd docker} msg o
  catch {exec useradd -r -u 1000 -g docker -s /bin/false che} msg o
}

proc ::CheInstaller::startStop {action} {
  cd [getAppFolder]
  exec nohup runuser -u che ./bin/che.sh $action &
}

proc ::CheInstaller::createDockRepo {} {
  variable dockRepo
  variable dockRepoContent
  if {[catch {open $dockRepo w} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    puts $fid $dockRepoContent
    close $fid
  }
}
