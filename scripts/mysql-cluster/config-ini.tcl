package provide confini 1.0
package require CommonUtil

namespace eval ::confini {
  set iniFile [file join $::baseDir mysql-cluster templates manage-node config.ini]
  if {[catch {open $iniFile} fid o]} {
    puts stderr $fid
    exit 1
  } else {
    set lines [list]
    while {[gets $fid line] >= 0} {
      lappend lines $line
    }
    close $fid
    variable iniDic [::CommonUtil::splitSeg $lines {\[*]}]
  }
}


proc ::confini::writeToDisk {dest {needSubstitute 0}} {
  if {$needSubstitute} {
    substitute
  }
  set configDir [file dirname $dest]
  variable iniDic

  if {! [file exists $configDir]} {
    exec mkdir -p $configDir
  }

  if {[catch {open $dest w} fid o]} {
    puts stderr $fid
    exit 1
  } else {
    dict for {k v} $iniDic {
      foreach line $v {
          puts $fid $line
      }
      puts $fid \n
    }
    close $fid
  }
}

#{[NDB_MGMD DEFAULT]} {[NDB_MGMD]} {[NDBD DEFAULT]} {[NDBD]} {[MYSQLD DEFAULT]} {[MYSQLD]} {[API]}
proc ::confini::substitute {} {
  variable iniDic
  set tmpDic [dict create]

  dict for {k v} $iniDic {
    switch $k {
      {[NDB_MGMD DEFAULT]} -
      {[NDBD DEFAULT]} -
      {[MYSQLD DEFAULT]} {
        set ymlKey [string map {{ } _} [string range $k 1 end-1]]
        set dic [dict get $::ymlDict $ymlKey]
        dict set tmpDic $k [::CommonUtil::replace $v $dic]
      }
      {[NDB_MGMD]} -
      {[NDBD]} -
      {[MYSQLD]} {
        set ymlKey [string map {{ } _} [string range $k 1 end-1]]
        set nodes [dict get $::ymlDict $ymlKey nodes]
        set tmpList [list]
        foreach ndic $nodes {
          set afterReplaced [concat [::CommonUtil::replace $v $ndic] \n]
          set tmpList [concat $tmpList $afterReplaced]
        }
        dict set tmpDic $k $tmpList
      }
      {[API]} {
        set ymlKey [string map {{ } _} [string range $k 1 end-1]]
        set nodes [dict get $::ymlDict $ymlKey]
        set tmpList [list]
        foreach ndic $nodes {
          set tmpList [concat $tmpList [::CommonUtil::replace $v $ndic]]
        }
        dict set tmpDic $k $tmpList
      }
    }
  }
  variable iniDic $tmpDic
}
