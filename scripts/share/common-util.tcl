package provide CommonUtil 1.0

package require yaml

namespace eval ::CommonUtil {

}

proc ::CommonUtil::dictItemExists {} {

}

proc ::CommonUtil::replace {lines kvDic} {
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

proc ::CommonUtil::replaceItem {contentDic contentKey kvDic} {
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
  catch {[set dt [::yaml::yaml2dict -file $fn]]} msg o
  if {! ([dict get $o -errorcode] eq {NONE})} {
    puts stderr $msg
    exit 1
  }
  return $dt
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

proc ::CommonUtil::backupOrigin {fn} {
  if {[file exists $fn]} {
    set of "$fn.origin"
    if {! [file exists $of]} {
      exec cp $fn $of
    }
  }
}
