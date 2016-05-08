package provide PropertyUtil 1.0

package require Expect

package require CommonUtil

namespace eval ::PropertyUtil {

}

proc ::PropertyUtil::split2pair {line} {
  set trimed [string trim $line]
  if {[string first # trimed] != 0} {
    if {[regexp  {(.*)=([^#[:space:]]+)} $line mh m1 m2]} {
      return [list $m1 $m2]
    }
  }
  return [list]
}

proc ::PropertyUtil::properties2dict {fn} {
  set d [dict create]
  if {[catch {open $fn} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    while {[gets $fid line] >= 0} {
      set pair [split2pair $line]
      if {[llength $pair] == 2} {
        dict set d [lindex $pair 0] [lindex $pair 1]
      }
    }
    close $fid
    return $d
  }
}

proc ::PropertyUtil::isCommentLine {line} {
  set trimed [string trim $line]
  if {[string first # trimed] == 0} {
    return 1
  } else {
    return 0
  }
}

proc ::PropertyUtil::commentLines {fn keylist} {
  set lines [list]
  if {[catch {open $fn} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    while {[gets $fid line] >= 0} {
      set pair [split2pair $line]
      if {[llength $pair] == 2 && [lsearch -exact $keylist [lindex $pair 0]] != -1} {
        lappend lines "#$line"
      } else {
        lappend lines $line
      }
    }
    close $fid
  }
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

proc ::PropertyUtil::unCommentLines {fn keylist} {
  set lines [list]
  if {[catch {open $fn} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    while {[gets $fid line] >= 0} {
      if {[regexp {^#+(.+)=([^#[:space:]]+)} $line mh m1 m2] && [lsearch -exact $keylist $m1] != -1} {
        lappend lines "${m1}=$m2"
      } else {
        lappend lines $line
      }
    }
    close $fid
  }
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
