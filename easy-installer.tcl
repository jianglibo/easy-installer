#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

set favoriteMirror aliyun.com
set serverSideDir ~/easy-install/scripts

# paramter format: --name=value
set nameActions [list]

set ::baseDir [file dirname [info script]]
lappend auto_path [file join $::baseDir client-side]

package require CcommonUtil
package require ParamsValidator
package require Expect

set rawParamDict [dict create]

foreach a $::argv {
  set pair [split $a =]
  if {[llength $pair] == 2} {
    dict set rawParamDict [string trimleft [lindex $pair 0] -] [lindex $pair 1]
  } else {
    lappend nameActions $a
  }
}

::ParamsValidator::validate rawParamDict $nameActions

set properties [::CcommonUtil::parseClientProperties [dict get $rawParamDict appname]]

foreach h [::CcommonUtil::parseHosts [dict get $rawParamDict host]] {
  #if you not living main land of china, comment line below.
  ::CcommonUtil::prepareRunFolder $h $serverSideDir rawParamDict
  if {[dict exists $rawParamDict runBash] || ([string length [dict get $rawParamDict mocklist]] > 0)} {
    puts "running very early bash......."
    ::CcommonUtil::runVeryEarlyBash $h $rawParamDict
  }
  set actions [lrange $nameActions 1 end]
  foreach action $actions {
    if {$action eq {copyLibs}} {
      ::CcommonUtil::copyLibs $h $serverSideDir $rawParamDict
    }

    if {$action eq {exec}} {
      set cmd [dict get $rawParamDict cmd]
      exec ssh root@$h $cmd
      continue
    }
    spawn -noecho ssh root@$h
    exp_send "tclsh [file join $serverSideDir launcher.tcl] [::CcommonUtil::prepareLauncherParams $h $rawParamDict $action]\n"
    set timeout 100000
    # all we need is to keep sensitive password out of command history.
    expect {
      "_enter_password:$" {
        expect_user -re "(.*)\n"
        exp_send "$expect_out(1,string)\n"
        exp_continue
      }
      "_enter_value:$" {
        expect_user -re "(.*)\n"
        exp_send "$expect_out(1,string)\n"
        exp_continue
      }
      "end_of_easy_install" {
        close
      }
      -re "(.*)\n" {
        exp_continue
      }
      eof {}
      timeout
    }
  }
  ::CcommonUtil::cleanup $h
}

#proc changeMirrors {host} {
#  puts "modify yum repo."
#  exec ssh root@$host "sed -i -e 's/#include_only.*/include_only=$::favoriteMirror/' /etc/yum/pluginconf.d/fastestmirror.conf"
#}

#proc installTclIfNeed {host} {
#  catch {exec ssh root@$host "which tclsh"} msg o
#  if {[dict get $o -code] == 1} {
#    set timeout 10000
#    spawn ssh root@$host "yum install -y tcl tcllib expect dos2unix yum-cron;systemctl enable yum-cron;systemctl start yum-cron"
#    expect {
#      eof {}
#    }
#  }

#  catch {exec ssh root@$host "which expect"} msg o
#  if {[dict get $o -code] == 1} {
#    spawn ssh root@$host "yum install -y expect"
#    expect {
#      eof {}
#    }
#  }
#}
