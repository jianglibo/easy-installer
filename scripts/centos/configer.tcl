package provide Configer 1.0

namespace eval ::Configer {
  variable urlDic [dict create]
  dict set urlDic aliyun http://mirrors.aliyun.com
}

proc ::Configer::disableIpv6 {} {
  if {[catch {open /etc/sysctl.conf a+} fid o]} {
    puts $fid
  } else {
    puts $fid \n
    puts $fid "net.ipv6.conf.all.disable_ipv6=1"
    puts $fid "net.ipv6.conf.default.disable_ipv6=1"
    close $fid
  }

  exec sysctl -w net.ipv6.conf.all.disable_ipv6=1
  exec sysctl -w net.ipv6.conf.default.disable_ipv6=1
}

proc ::Configer::fixCentOsBase {cfgFile url} {
  set scripts {
      if {[string first mirrorlist= $line] == 0} {
        lappend lines "#$line"
      } elseif {[string first #baseurl= $line] == 0} {
        lappend lines [string map "#baseurl= baseurl= http://mirror.centos.org %s" $line]
      } else {
        lappend lines $line
      }
  }
  set scripts [format $scripts $url]
  ::CommonUtil::substFileLineByLine $cfgFile $scripts
}

proc ::Configer::fixAliEpel {cfgFile} {
  set scripts {
      if {! [string match *aliyuncs* $line]} {
        lappend lines $line
      }
    }
  ::CommonUtil::substFileLineByLine $cfgFile $scripts
}

proc ::Configer::disableFastMirror {} {
  set cfgFile /etc/yum/pluginconf.d/fastestmirror.conf
  set scripts {
    if {[string first enabled= $line] == 0} {
      lappend lines enabled=0
    } else {
      lappend lines $line
    }
  }
  ::CommonUtil::substFileLineByLine $cfgFile $scripts
}

proc ::Configer::backupRepo {} {
  set bakName /etc/yum.repos.d-bak
  if {! [file exists $bakName]} {
    exec cp -R /etc/yum.repos.d $bakName
  }
  catch {
    exec rm -rvf /etc/yum.repos.d/epel.repo
    exec rm -rvf /etc/yum.repos.d/epel-testing.repo
  } msg o
}

#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os&infra=$infra
#baseurl=http://mirror.centos.org/centos/$releasever/os/$basearch/
# http://mirrors.aliyun.com/centos/
# CentOS-Base.repo  CentOS-CR.repo CentOS-Debuginfo.repo  CentOS-fasttrack.repo  CentOS-Media.repo CentOS-Sources.repo CentOS-Vault.repo
proc ::Configer::fixRepoTo {src} {
  variable urlDic

  backupRepo
  disableFastMirror

  catch {exec curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo} msg o

  fixCentOsBase /etc/yum.repos.d/CentOS-Base.repo [dict get $urlDic $src]
  fixAliEpel /etc/yum.repos.d/epel.repo
}
