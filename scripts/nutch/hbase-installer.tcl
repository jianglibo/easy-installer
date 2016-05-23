package provide HbaseInstaller 1.0
package require CommonUtil
package require PropertyUtil
package require OsUtil
package require XmlWriter

namespace eval HbaseInstaller {
  variable installFolder /opt/hbase
  variable profiled /etc/profile.d/hbase.sh
}

proc ::HbaseInstaller::setupEnv {hbaseHome ymlDict rawParamDict} {
  variable profiled
  if {[catch {set javaLink [exec which java]} msg o]} {
    puts $msg
    ::CommonUtil::endEasyInstall
  }
  while {[file type $javaLink] eq {link}} {
    set javaLink [file readlink $javaLink]
  }
  set javaLink [file normalize [file join $javaLink .. ..]]

  set lines [list]
  lappend lines "JAVA_HOME=$javaLink"
  lappend lines "export JAVA_HOME"

  if {[catch {open $profiled w} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    foreach line $lines {
      if {[regexp {^(.*)=(.*)$} $line mh mk mv]} {
        set ::env($mk) $mv
      }
      puts $fid $line
    }
    close $fid
  }
}

proc ::HbaseInstaller::gethbaseHome {ymlDict} {
  variable installFolder

  if {! [file exists $installFolder]} {
    exec mkdir -p $installFolder
  }

  set pwd [pwd]
  set from [dict get $ymlDict DownFrom]
  set fn [lindex [split $from /] end]

  cd $installFolder

  if {! [file exists $fn]} {
    ::CommonUtil::spawnCommand curl -OL $from
  }

  set extractedFolder [glob -nocomplain -directory $installFolder -type d *]
  puts [llength $extractedFolder]
  if {[llength $extractedFolder] == 0} {
    if {[catch {exec tar -zxf $fn} msg o]} {
      puts "$fn is damaged. please try again."
      exec rm -f $fn
      exec rm -rf $extractedFolder
      ::CommonUtil::endEasyInstall
    }
  }

  set extractedFolder [glob -nocomplain -directory $installFolder -type d *]
  return [file normalize [lindex $extractedFolder 0]]
}

proc ::HbaseInstaller::copyConfFile {hbaseHome runFolder args} {
  set runFolder [file join $::baseDir $runFolder]
  set hbaseConfFolder  [file join $hbaseHome conf]
  foreach f $args {
    set src [file join $runFolder $f]
    set dst [file join $hbaseConfFolder $f]
    ::CommonUtil::backupOrigin $dst
    exec cp -f $src $dst
    exec -ignorestderr dos2unix $dst
  }
}

proc ::HbaseInstaller::install {ymlDict rawParamDict} {
  set hbaseHome [gethbaseHome $ymlDict]

  if {[catch {copyConfFile $hbaseHome [dict get $rawParamDict runFolder] hbase-site.xml regionservers backup-masters} msg o]} {
    puts $msg
    exec rm -rvf $hbaseHome
    puts "extraced folder is not complete. please try again."
    ::CommonUtil::endEasyInstall
  }


  puts "install successfully."
  puts "please login to master server, and setup passwordless login to other servers."
}

proc ::HbaseInstaller::startStop {ymlDict rawParamDict action} {
  set hbaseHome [gethbaseHome $ymlDict]

  if {! ([dict get $ymlDict MasterIp] eq [dict get $rawParamDict host])} {
    puts "please invoke start stop from master server: [dict get $rawParamDict host]."
    ::CommonUtil::endEasyInstall
  }

  switch -exact -- $action {
    start {
      ::CommonUtil::spawnCommand [file join $hbaseHome bin start-hbase.sh]
    }
    stop {
      ::CommonUtil::spawnCommand [file join $hbaseHome bin stop-hbase.sh]
    }
    default {}
  }


}
