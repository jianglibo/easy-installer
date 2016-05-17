package provide HadoopInstaller 1.0
package require CommonUtil
package require PropertyUtil
package require OsUtil
package require XmlWriter

namespace eval HadoopInstaller {
  variable installFolder /opt/hadoop
  variable profiled /etc/profile.d/hadoop.sh
}

proc ::HadoopInstaller::setupEnv {hadoopHome ymlDict rawParamDict} {
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
  lappend lines "HADOOP_PREFIX=${hadoopHome}"
  lappend lines "export HADOOP_PREFIX"
  lappend lines "HADOOP_PID_DIR=[file join $hadoopHome piddir]"
  lappend lines "export HADOOP_PID_DIR"
  lappend lines "HADOOP_LOG_DIR=[file join $hadoopHome logs]"
  lappend lines "export HADOOP_LOG_DIR"

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
#  if {[llength [array names ::env -regexp {JAVA_HOME|HADOOP_PREFIX|HADOOP_PID_DIR|HADOOP_LOG_DIR}]] != 4} {
#    puts "start rebooting....."
#    puts "please run command again!"
#    exec shutdown -r now
#    ::CommonUtil::endEasyInstall
#  }
}

proc ::HadoopInstaller::getHadoopHome {ymlDict} {
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
  return [file normalize $m1]
}

proc ::HadoopInstaller::install {ymlDict rawParamDict} {
  set hadoopHome [getHadoopHome $ymlDict]

  ::OsUtil::createUserNotLogin hadoop
  setupEnv $hadoopHome $ymlDict $rawParamDict

  set myNodes [::YamlUtil::getHostYmlNodes $ymlDict $rawParamDict]

  foreach node $myNodes {
    set role [dict get $node role]
    ::XmlWriter::coreSite $hadoopHome $node
    switch -exact -- $role {
      NameNode {
        ::XmlWriter::hdfsSite $hadoopHome $node
        ::OsUtil::openFirewall tcp 8020 50070
      }
      DataNode {
        ::XmlWriter::hdfsSite $hadoopHome $node
        ::OsUtil::openFirewall tcp 43067 50020 50010
      }
      ResourceManager {
        ::XmlWriter::yarnSite $hadoopHome $node
        ::OsUtil::openFirewall tcp 8030 8031 8032 8033 8088
      }
      NodeManager {
        ::XmlWriter::yarnSite $hadoopHome $node
        ::OsUtil::openFirewall tcp 57310 8040 8042
      }
      default {}
    }
  }
}

proc ::HadoopInstaller::getBinCmd {hadoopHome cmd} {
  return [file normalize [file join $hadoopHome bin $cmd]]
}

proc ::HadoopInstaller::getSbinCmd {hadoopHome cmd} {
  return [file normalize [file join $hadoopHome sbin $cmd]]
}

proc ::HadoopInstaller::formatCluster {ymlDict rawParamDict} {
  set hadoopHome [getHadoopHome $ymlDict]
  set myNodes [::YamlUtil::getHostYmlNodes $ymlDict $rawParamDict]
  foreach node $myNodes {
    set role [dict get $node role]
    switch -exact -- $role {
      NameNode {
        set timeout 10000
        spawn [getBinCmd $hadoopHome hdfs] namenode -format [dict get $ymlDict ClusterName]
        expect {
          "*Re-format filesystem in Storage Directory*" {
            exp_send "N\r"
            puts "alreay formatted, skip."
          }
          eof {
            puts done
          }
          timeout {
            puts timeout
          }
        }
      }
      default {}
    }
  }
}

proc ::HadoopInstaller::startStop {ymlDict rawParamDict action} {
  set hadoopHome [getHadoopHome $ymlDict]

  set myNodes [::YamlUtil::getHostYmlNodes $ymlDict $rawParamDict]

  foreach node $myNodes {
    set role [dict get $node role]
    switch -exact -- $role {
      NameNode {
        ::CommonUtil::spawnCommand [getSbinCmd $hadoopHome hadoop-daemon.sh] --script hdfs $action namenode
      }
      DataNode {
        ::CommonUtil::spawnCommand [getSbinCmd $hadoopHome hadoop-daemon.sh] --script hdfs $action datanode
      }
      ResourceManager {
        ::CommonUtil::spawnCommand [getSbinCmd $hadoopHome yarn-daemon.sh] $action resourcemanager
      }
      NodeManager {
        ::CommonUtil::spawnCommand [getSbinCmd $hadoopHome yarn-daemon.sh] $action nodemanager
      }
      default {}
    }
  }
}

proc ::HadoopInstaller::report {ymlDict rawParamDict} {
  set hadoopHome [getHadoopHome $ymlDict]
  ::CommonUtil::spawnCommand [getBinCmd $hadoopHome hdfs] dfsadmin -report
}
