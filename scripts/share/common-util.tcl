package provide CommonUtil 1.0

package require yaml

package require Expect

namespace eval ::CommonUtil {

}

proc ::CommonUtil::getOnlyFolder {parentFolder} {
  return [glob -nocomplain -directory $parentFolder -type d *]
}

proc ::CommonUtil::endEasyInstall {} {
  puts stdout "\nend_of_easy_install\n"
  exit 0
}

proc ::CommonUtil::lnewItems {listBefore listAfter} {
  list newItems [list]
  foreach item $listAfter {
    if {[lsearch -exact $listBefore $item] == -1} {
      lappend newItems $item
    }
  }
  return newItems
}

proc ::CommonUtil::spawnCommand {args} {
  set timeout 10000
  spawn {*}$args
  expect {
    * {
      expect_continue
    }
    eof {
      puts done
    }
    timeout {
      puts timeout
    }
  }
}

proc ::CommonUtil::sysRunning {serviceName} {
  if {[catch {exec systemctl status $serviceName} msg o]} {
    return 0
  } else {
    if {[string match *(running)* $msg]} {
      return 1
    } else {
      return 0
    }
  }
}

proc ::CommonUtil::sysInstalled {serviceName} {
  if {[catch {exec systemctl status $serviceName} msg o]} {
    if {[string match "*Loaded: loaded*" $msg]} {
      return 1
    } else {
      return 0
    }
  } else {
    return 1
  }
}

proc ::CommonUtil::substFileLineByLine {fn scripts {toAppends {}}} {
  set lines [list]
  if {[catch {open $fn} fid o]} {
    puts stdout $fid
  } else {
    while {[gets $fid line] >= 0} {
      eval $scripts
    }
    close $fid
  }

  if {[catch {open $fn w} fid o]} {
    puts stdout $fid
  } else {
    foreach line $lines {
      puts $fid $line
    }
    foreach toapp $toAppends {
      puts $fid $toapp
    }
    close $fid
  }
}

proc ::CommonUtil::replaceLines {lines kvDic} {
  set keys [dict keys $kvDic]
  set result [list]

  foreach line $lines {
    foreach k $keys {
      if {[string first "$k=" $line] == 0} {
        set line [string replace $line [string length "$k="] end [dict get $kvDic $k]]
        break
      }
    }
    lappend result $line
  }
  return $result
}


proc ::CommonUtil::replaceFileContent {fn kvDic} {
  if {[catch {open $fn} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    set lines [list]
    while {[gets $fid line] >= 0} {
      lappend lines $line
    }
    close $fid
    return [replaceLines $lines $kvDic]
  }
}

proc ::CommonUtil::replaceFileContentInLine {fn kvDic} {
  set lines [replaceFileContent $fn $kvDic]
  if {[catch {open $fn w} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    foreach line $lines {
      puts $fid $line
    }
    close $fid
  }
}

proc ::CommonUtil::replaceContentDic {contentDic contentKey kvDic} {
  set lines [dict get $contentDic $contentKey]
  set lines [replace $lines $kvDic]
  dict set contentDic $contentKey $lines
  return $contentDic
}

# leading lines are tripped.
proc ::CommonUtil::splitSeg {lines matcher} {
  set rd [dict create]
  set lastMatch {}
  set seg [list]
  foreach line $lines {
    if {[string match $matcher $line]} {
      if {[string length $lastMatch] > 0} {
        dict set rd $lastMatch $seg
        set seg [list]
        set lastMatch $line
      } else {
        set lastMatch $line
      }
    }
    lappend seg $line
  }
  if {[llength $seg] > 0} {
    dict set rd $lastMatch $seg
  }
  return $rd
}

proc ::CommonUtil::getMgmHosts {ymlDict} {
  set hosts [list]
  dict for {k v} $ymlDict {
    switch $k {
      {NDB_MGMD} {
        foreach n [dict get $v nodes] {
          lappend hosts "[dict get $n HostName]:[dict get $n PortNumber]"
        }
      }
    }
  }
  return $hosts
}

proc ::CommonUtil::loadNormalizedYmlDic {fn} {
  ::CommonUtil::normalizeYmlCfg [::CommonUtil::loadYaml $fn]
}

proc ::CommonUtil::loadYaml {fn} {
  if {[catch {set dt [::yaml::yaml2dict -file $fn]} msg o]} {
    puts $msg
    endEasyInstall
  } else {
    return $dt
  }
}



proc ::CommonUtil::getThisMachineIp {configIpList} {
  foreach mip [getMachineIps] {
    if {[lsearch -exact $configIpList $mip] != -1} {
      return $mip
    }
  }
  return {}
}

proc ::CommonUtil::getMachineIps {} {
    set thisMachineIps [list]
    set ipaddr [exec ip addr]
    foreach line [split $ipaddr \n] {
      set mt {}
      set ip {}
      regexp {inet\s+(\d+\.\d+\.\d+\.\d+)} $line mt ip
      if {[string length $ip] > 0} {
        lappend thisMachineIps $ip
      }
    }
    return $thisMachineIps
}

proc ::CommonUtil::normalizeYmlCfg {dic} {
  set newnodes [list]
  set mysqldSeg [dict get $dic MYSQLD]
  set baseDataDir [dict get $mysqldSeg DataDir]
  foreach n [dict get $mysqldSeg nodes] {
    foreach ins [dict get $n instances] {
      set nn [dict create]
      dict set nn HostName [dict get $n HostName]
      dict set nn DataDir "${baseDataDir}/[dict get $ins NodeId]"
      dict for {k v} $ins {
        dict set nn $k $v
      }
      lappend newnodes $nn
    }
  }
  dict set dic MYSQLD nodes $newnodes

  dict for {k v} $dic {
    switch $k {
      NDB_MGMD -
      NDBD -
      MYSQLD {
        set segKeys [dict keys $v]

        set newnodes [list]
        foreach n [dict get $v nodes] {
          foreach sk $segKeys {
            if {! [expr {$sk eq {nodes}}]} {
              if {! [dict exists $n $sk]} {
                dict set n $sk [dict get $v $sk]
              }
            }
          }
          lappend newnodes $n
        }
        dict set dic $k nodes $newnodes
      }
    }
  }
  return $dic
}

proc ::CommonUtil::mergeConfig {rawParamDict ymlDict} {
  dict for {k v} $rawParamDict {
      set ks [split $k .]
      if {[dict exists $ymlDict {*}$ks]} {
        dict set ymlDict {*}$ks $v
      }
  }
  return $ymlDict
}

proc ::CommonUtil::readWholeFile {fileName} {
  if {[catch {open $fileName} fid o]} {
    puts $fid
    endEasyInstall
  } else {
    set data [read $fileName]
    close $fid
  }
  return $data
}

proc ::CommonUtil::readLines {fn} {
  set lines [list]
  if {[catch {open $fn} fid o]} {
    puts $fid
    endEasyInstall
  } else {
    while {[gets $fid line] >= 0} {
      lappend lines $line
    }
    close $fid
  }
  return $lines
}

proc ::CommonUtil::backupOrigin {fn} {
  if {[file exists $fn]} {
    set of "$fn.origin"
    if {! [file exists $of]} {
      exec cp $fn $of
    }
  }
}

proc ::CommonUtil::writeLines {fn lines} {
  if {[catch {open $fn w} fid o]} {
    puts $fid
    endEasyInstall
  } else {
    foreach line $lines {
      puts $fid $line
    }
    close $fid
  }
}

proc ::CommonUtil::write {fn content} {
  if {[catch {open $fn w} fid o]} {
    puts $fid
    endEasyInstall
  } else {
    puts $fid $content
    close $fid
  }
}

proc ::CommonUtil::downloadIfNeeded {url extractor} {
  set fn [lindex [split $url /] end]
  if {[file exists $fn]} {
    puts "$fn already download, skipped."
  } else {
    ::CommonUtil::spawnCommand curl -OL $url
  }

  set extrated [getOnlyFolder [pwd]]
  if {[file exists $extrated]} {
    puts "$extrated alreay exists, skipped."
  } else {
    set cmd [split $extractor { }]
    lappend cmd $fn
    exec {*}$cmd
  }
}
