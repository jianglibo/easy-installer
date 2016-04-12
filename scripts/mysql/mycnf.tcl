package provide Mycnf 1.0

package require CommonUtil

namespace eval ::Mycnf {
  set mycnfFile [file join $::baseDir mysql my.cnf]
  if {[catch {open $mycnfFile} fid o]} {
    puts stderr $fid
    exit 1
  } else {
    set lines [list]
    while {[gets $fid line] >= 0} {
      lappend lines $line
    }
    close $fid
    variable mycnfDic [::CommonUtil::splitSeg $lines {\[*]}]
  }
}

proc ::Mycnf::writeToDisk {dest nodeYml {needSubstitute 0}} {
  if {$needSubstitute} {
    substitute $nodeYml
  }

  set configDir [file dirname $dest]
  variable iniDic

  if {! [file exists $configDir]} {
    exec mkdir -p $configDir
  }

  ::CommonUtil::backupOrigin $dest

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


proc ::Mycnf::substitute {nodeYml} {
  variable mycnfDic
  set tmpDic [dict create]

  dict for {k v} $mycnfDic {
    switch $k {
      {[mysqld]} {
        dict set tmpDic $k [::CommonUtil::replace $v $nodeYml]
      }
    }
  }
  variable mycnfDic $tmpDic
}
