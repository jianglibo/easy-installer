package provide CcommonUtil 1.0

namespace eval ::CcommonUtil {

}

proc ::CcommonUtil::parseClientProperties {appname} {
  set properties [dict create]
  set pf [file join $::baseDir scripts $appname client.properties]
  if {[file exists $pf]} {
    if {[catch {open $pf} fid o]} {
      puts $fid
      exit 0
    } else {
      while {[gets $fid line] >= 0} {
        if {[regexp {^([^#[:space:]]+)\s*=\s*([^#[:space:]+])} $line mh m1 m2]} {
          dict set properties $m1 $m2
        }
      }
      close $fid
    }
  }
  return properties
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
  upvar $rawParamDict rpd

  set appname [dict get $rpd appname]
  puts "start prepare run folder on server $host...."
  puts [exec ssh root@$host "mkdir -p $serverSideDir"]
  puts [exec scp -r [file join $::baseDir scripts $appname]  root@$host:$serverSideDir]
  puts [exec scp -r [file join $::baseDir scripts share]  root@$host:$serverSideDir]
  set tmp [glob -types f -directory [file join $::baseDir scripts] -- *.*]
  foreach f $tmp {
    exec scp $f root@$host:$serverSideDir
  }
  set mocklist [dict get $rpd mocklist]
  if {[string length $mocklist] > 0} {
    exec scp [file join $::baseDir mocklist $mocklist] root@$host:$serverSideDir
  }

  if {$appname eq {boot}} {
      puts [exec scp [dict get $rpd bootjar] root@$host:$serverSideDir]
  }

  if {[dict exists $rpd profile]} {
    set profile [dict get $rpd profile]
  } else {
    set profile default.yml
  }

  if {! [regexp {.*\.yml$} $profile mh]} {
    set profile "${profile}.yml"
  }

  if {! [file exists [file join $::baseDir scripts $appname profiles $profile]]} {
    puts "please browser scripts/$appname/profiles, there is no default.yml, please add a --profile=xxx.yml parameter."
    exit 0
  }
#  puts [exec scp [file join $::baseDir scripts $appname profiles $profile] root@$host:$serverSideDir]
  dict set rpd profile $profile
}

proc ::CcommonUtil::prepareLauncherParams {host rawParamDict action} {
  set params [list]
  dict for {k v} $rawParamDict {
    switch -exact -- $k {
      bootjar {
        lappend params "--$k=[file tail $v]"
      }
      mocklist {
        if {[string length $v] > 0} {
          lappend params "--$k=$v"
        }
      }
      host {
      }
      appname {
        puts "skip appname parameter."
      }
      default {
        lappend params "--$k=$v"
      }
    }
  }
  lappend params "--host=$host"
  lappend params "--runFolder=[dict get $rawParamDict appname]"
  lappend params "--action=$action"
  puts "copy scrits done."
  return [join $params { }]
}

proc ::CcommonUtil::cleanup {host} {
  spawn ssh root@$host "tclsh [file join $::serverSideDir after-install.tcl]"
  expect {
    eof {}
  }
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
    "end_of_easy_install" {
      close
      cleanup $host
      exit 0
    }
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
