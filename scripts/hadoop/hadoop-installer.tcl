package provide HadoopInstaller 1.0
package require CommonUtil
package require PropertyUtil
package require OsUtil

namespace eval HadoopInstaller {
  variable installFolder /opt/hadoop
  variable profiled /etc/profile.d/hadoop.sh
}

proc ::HadoopInstaller::setupEnv {isf ymlDict rawParamDict} {
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
  lappend lines "HADOOP_PREFIX=${isf}"
  lappend lines "export HADOOP_PREFIX"
  lappend lines "HADOOP_PID_DIR=[file join $isf piddir]"
  lappend lines "export HADOOP_PID_DIR"
  lappend lines "HADOOP_LOG_DIR=[file join $isf logs]"
  lappend lines "export HADOOP_LOG_DIR"

  if {[catch {open $profiled w} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    foreach line $lines {
      puts $fid $line
    }
    close $fid
  }

  puts "start rebooting....."
  exec shutdown -r now
  ::CommonUtil::endEasyInstall
}

proc ::HadoopInstaller::install {ymlDict rawParamDict} {
  variable installFolder

  if {! [file exists $installFolder]} {
    exec mkdir -p $installFolder
  }

  set pwd [pwd]
  set from [dict get $ymlDict DownFrom]
  set fn [lindex [split $from /] end]
  if {! [regexp {(.*)\.tar\.gz$} $fn mh m1]} {
    puts "cann't parse folder name from $fn"
    ::CommonUtil::endEasyInstall
  }
  cd $installFolder
  if {! [file exists $fn]} {
    ::CommonUtil::spawnCommand curl -OL $from
  }

  if {! [file exists $m1]} {
    if {[catch {exec tar -zxf $fn} msg o]} {
      puts "$fn is damaged. please try again."
      exec rm -f $fn
      exec rm -rf $m1
      ::CommonUtil::endEasyInstall
    }
  }
  ::OsUtil::createUserNotLogin hadoop
  setupEnv [file normalize $m1] $ymlDict $rawParamDict
}
