package provide CcommonUtil 1.0

namespace eval ::CcommonUtil {

}

proc ::CcommonUtil::printHelp {} {
  puts "command style is:"
  puts "easy-install.tcl -host=xxx --profile=xxx --otherparams=xxx appname action...action."
  puts "for example: easy-install.tcl -host=192.168.33.50 java install"
}

proc ::CcommonUtil::isAppName {appname} {
  set tmp [glob -types d -directory [file join $::baseDir scripts] -tails -- *]
  foreach it $tmp {
    if {[string equal $appname $it]} {
      return 1
    }
  }
  return 0
}

proc ::CcommonUtil::cleanupRunFolder {host} {
  puts "start cleanup run folder on server $host...."
  exec ssh root@$host "rm -rvf ~/easy-install"
  puts done!
}

proc ::CcommonUtil::prepareRunFolder {host serverSideDir rawParamDict} {
  set appname [dict get $rawParamDict appname]
  puts "start prepare run folder on server $host...."
  puts [exec ssh root@$host "mkdir -p $serverSideDir"]
  puts [exec scp -r [file join $::baseDir scripts $appname]  root@$host:$serverSideDir]
  puts [exec scp -r [file join $::baseDir scripts share]  root@$host:$serverSideDir]
  set tmp [glob -types f -directory [file join $::baseDir scripts] -- *.*]
  foreach f $tmp {
    exec scp $f root@$host:$serverSideDir
  }
  set mocklist [dict get $rawParamDict mocklist]
  if {[string length $mocklist] > 0} {
    exec scp [file join $::baseDir $mocklist] root@$host:$serverSideDir
  }
  if {$appname eq {boot}} {
      puts [exec scp -r [dict get $rawParamDict bootjar] root@$host:$serverSideDir]
  }
}

proc ::CcommonUtil::prepareLauncherParams {rawParamDict action} {
  set params [list]
  dict for {k v} $rawParamDict {
    switch -exact -- $k {
      host {
        puts "skip host parameter."
      }
      bootjar {
        lappend params "--$k=[file tail $v]"
      }
      mocklist {
        if {[string length $v] > 0} {
          lappend params "--$k=$v"
        }
      }
      appname {
        puts "skip appname parameter."
      }
      default {
        lappend params "--$k=$v"
      }
    }
  }
  lappend params "--runFolder=[dict get $rawParamDict appname]"
  lappend params "--action=$action"
  puts "copy scrits done."
  return [join $params { }]
}

proc ::CcommonUtil::runVeryEarlyBash {host rawParamDict} {
  set mocklist [dict get $rawParamDict mocklist]
  set timeout 100000
  if {[string length $mocklist] > 0} {
    set ml " $mocklist"
  } else {
    set ml {}
  }
  spawn ssh root@$host "cd ${::serverSideDir};sed -i 's/\r//' very-early.bash;bash very-early.bash$ml"
  expect {
    eof {}
  }
}

proc ::CcommonUtil::parseHosts {hoststr} {
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
