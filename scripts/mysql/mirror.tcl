package provide Mirror 1.0

package require Expect

namespace eval ::Mirror {

}

#rsync://mysql.he.net/mysql/
#rsync://ftp5.gwdg.de/pub/linux/mysql/
#rsync://rsync.mirrorservice.org/ftp.mysql.com/
#rsync://rsync.oss.eznetsols.org/ftp/mysql/

proc ::Mirror::mirror {rawParamDict} {
  set atExists [dict exists $rawParamDict at]
  set diskPathExists [dict exists $rawParamDict disk-path]
  set srcExists [dict exists $rawParamDict src]
  if {$atExists} {
    set at [dict get $rawParamDict at]
  } else {
    set at 5:10
  }

  if {$diskPathExists} {
    set diskPath [dict get $rawParamDict disk-path]
  } else {
    set diskPath "/mount/mysqlmirror/"
  }

  if {$srcExists} {
    set src [dict get $rawParamDict src]
  } else {
    set src "rsync://mysql.he.net/mysql/"
  }

  set mh [split $at :]
  set cronStr "%s */%s * * * rsync -a --delete --delete-after %s %s"
  set cronStr [format $cronStr [lindex $mh 1] [lindex $mh 0] $src $diskPath]
  if {[catch {open /etc/crontab a+} fid o]} {
    puts "open /etc/crontab failed."
  } else {
    puts $fid "\n$cronStr"
    close $fid
  }
}
