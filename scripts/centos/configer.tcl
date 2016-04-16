package provide Configer 1.0

namespace eval ::Configer {
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

proc ::Configer::fixOne {cfgFile url} {
  puts "${cfgFile}----$url"
  set lines [list]
  if {[catch {open $cfgFile} fid o]} {
    puts stdout $fid
  } else {
    while {[gets $fid line] >= 0} {
      if {[string first mirrorlist= $line] == 0} {
        lappend lines "#$line"
        lappend lines [join [list "baseurl=$url/centos/" {$releasever/updates/$basearch/}] {}]
      } else {
        lappend lines $line
      }
    }
    close $fid
  }

  if {[catch {open $cfgFile w} fid o]} {
    puts stdout $fid
  } else {
    foreach line $lines {
      puts $fid $line
    }
    close $fid
  }
}

proc ::Configer::disableFastMirror {} {
  set cfgFile /etc/yum/pluginconf.d/fastestmirror.conf
  set lines [list]
  if {[catch {open $cfgFile} fid o]} {
    puts stdout $fid
  } else {
    while {[gets $fid line] >= 0} {
      if {[string first enabled= $line] == 0} {
        lappend lines enabled=0
      } else {
        lappend lines $line
      }
    }
    close $fid
  }

  if {[catch {open $cfgFile w} fid o]} {
    puts stdout $fid
  } else {
    foreach line $lines {
      puts $fid $line
    }
    close $fid
  }
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
  backupRepo
  disableFastMirror

  set files {/etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Sources.repo}
  set url {}
  switch $src {
    aliyun {
      set url "http://mirrors.aliyun.com"
    }
  }

  catch {exec curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo} msg o

  if {[string length url] == 0} {
    puts "Known src: $src"
  } else {
    foreach f $files {
      fixOne $f $url
    }
  }
}
