#!/bin/sh
# install-java.tcl \
exec tclsh "$0" ${1+"$@"}

# paramter format: --name=value
set ::nameAction [list]

set ::baseDir [file dirname [info script]]
package require Expect

proc printHelp {} {
  puts "command style is:"
  puts "easy-install.tcl -host=xxx --otherparams=xxx appname action...action."
  puts "for example: easy-install.tcl -host=192.168.33.50 java install"
}

proc isAppName {an} {
  set tmp [glob -types d -directory [file join $::baseDir scripts] -tails -- *]
  foreach it $tmp {
    if {[string equal $an $it]} {
      return 1
    }
  }
  return 0
}

proc changeMirrors {host} {
  puts "modify yum repo."
  exec ssh root@$host "sed -i -e 's/#include_only.*/include_only=aliyun.com,.cn/' /etc/yum/pluginconf.d/fastestmirror.conf"
}

proc installTclIfNeed {host} {
  catch {exec ssh root@$host "which tclsh"} msg o
  if {[string match "which: no*" $msg]} {
    set timeout 10000
    spawn ssh root@$host "yum install -y tcl tcllib expect yum-cron;systemctl enable yum-cron;systemctl start yum-cron"
    expect {
      eof {}
    }
  }
}

proc parseHosts {hoststr} {
  set hosts [list]
  set tmp [split $hoststr ,]
  foreach h $tmp {
    set segs [split $h .]
    set sl [llength $segs]
    if {$sl < 4} {
      set tailers [expr 3 - $sl]
      lappend hosts [join [concat [lrange $lastSegs 0 $tailers] $segs] .]
    } else {
      set lastSegs $segs
      lappend hosts $h
    }
  }
  return $hosts
}

set ::rawParamDict [dict create]

foreach a $::argv {
  set pair [split $a =]
  if {[llength $pair] == 2} {
    dict set ::rawParamDict [string trimleft [lindex $pair 0] -] [lindex $pair 1]
  } else {
    lappend ::nameAction $a
  }
}

if {[llength $::nameAction] < 2} {
  printHelp
  exit 0
}

set ::appname [lindex $::nameAction 0]

if {! [dict exists $::rawParamDict host]} {
  printHelp
  exit 0
}

if {! [isAppName $::appname]} {
  puts "'$::appname' is not supported yet."
  exit 0
}

proc prepareRunFolder {host an} {
  puts "start prepare run folder on server $host...."
  puts [exec ssh root@$host "mkdir -p ~/easy-install/scripts"]
  puts [exec scp -r [file join $::baseDir scripts $an]  root@$host:~/easy-install/scripts/]
  puts [exec scp -r [file join $::baseDir scripts share]  root@$host:~/easy-install/scripts/]
  set tmp [glob -types f -directory [file join $::baseDir scripts] -- *.tcl]

  foreach f $tmp {
    exec scp $f root@$host:~/easy-install/scripts/
  }
}

proc cleanupRunFolder {host} {
  puts "start cleanup run folder on server $host...."
  exec ssh root@$host "rm -rvf ~/easy-install"
  puts done!
}

proc prepareLauncherParams {ac} {
  set params [list]
  dict for {k v} $::rawParamDict {
    switch -exact -- $k {
      host {
        puts {}
      }
      default {
        lappend params "--$k=$v"
      }
    }
  }
  lappend params "--runFolder=$::appname"
  lappend params "--action=$ac"
  puts "copy scrits done."
  return [join $params { }]
}

# start of app

foreach h [parseHosts [dict get $::rawParamDict host]] {
  #if you not living main land of china, comment line below.
  changeMirrors $h
  installTclIfNeed $h
  prepareRunFolder $h [lindex $::nameAction 0]

  set actions [lrange $::nameAction 1 end]
  foreach ac $actions {
    spawn -noecho ssh root@$h
    exp_send "tclsh ~/easy-install/scripts/launcher.tcl [prepareLauncherParams $ac]\n"
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
#    set execCmd "tclsh ~/easy-install/scripts/launcher.tcl [prepareLauncherParams $ac]"
#    puts "start run: $execCmd on $h"
#    catch {exec ssh root@$h $execCmd} msg o
#    puts $msg
  }
  cleanupRunFolder $h
}
