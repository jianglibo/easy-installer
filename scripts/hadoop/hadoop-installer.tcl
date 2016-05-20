package provide HadoopInstaller 1.0
package require CommonUtil
package require PropertyUtil
package require OsUtil
package require XmlWriter

namespace eval HadoopInstaller {
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
}

proc ::HadoopInstaller::getHadoopHome {ymlDict} {
  set dstFolder [dict get $ymlDict DstFolder]

  if {! [file exists $dstFolder]} {
    exec mkdir -p $dstFolder
  }

  set pwd [pwd]
  set from [dict get $ymlDict DownFrom]
  set fn [lindex [split $from /] end]

  cd $dstFolder
  if {! [file exists $fn]} {
    ::CommonUtil::spawnCommand curl -OL $from
  }

  set extractedFolder [::CommonUtil::getOnlyFolder $dstFolder]

  if {! [file exists $extractedFolder]} {
    if {[catch {exec tar -zxf $fn} msg o]} {
      puts "$fn is damaged. please try again."
      exec rm -f $fn
      exec rm -rf $m1
      ::CommonUtil::endEasyInstall
    }
  }
  return [file normalize $extractedFolder]
}

proc ::HadoopInstaller::install {ymlDict rawParamDict} {
  set hadoopHome [getHadoopHome $ymlDict]

  ::OsUtil::createUserNotLogin hadoop
  setupEnv $hadoopHome $ymlDict $rawParamDict

  set myNodes [::YamlUtil::getHostYmlNodes $ymlDict $rawParamDict]

  ::XmlWriter::mapred $hadoopHome $ymlDict
  ::XmlWriter::slaves $hadoopHome $ymlDict

  foreach node $myNodes {
    set role [dict get $node role]
    ::XmlWriter::coreSite $hadoopHome $node $ymlDict
    switch -exact -- $role {
      NameNode {
        ::XmlWriter::hdfsSite $hadoopHome $node $ymlDict
        ::OsUtil::openFirewall tcp 8020 50070
      }
      DataNode {
        ::XmlWriter::hdfsSite $hadoopHome $node $ymlDict
        ::OsUtil::openFirewall tcp 43067 50020 50010
      }
      ResourceManager {
        ::XmlWriter::yarnSite $hadoopHome $node $ymlDict
        ::OsUtil::openFirewall tcp 8030 8031 8032 8033 8088
      }
      NodeManager {
        ::XmlWriter::yarnSite $hadoopHome $node $ymlDict
        ::OsUtil::openFirewall tcp 57310 8040 8042 45467
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

proc ::HadoopInstaller::toggleFirewall {ymlDict rawParamDict} {
  if {[::CommonUtil::sysRunning firewalld]} {
    exec systemctl stop firewalld
  } else {
    exec systemctl start firewalld
  }
}

proc ::HadoopInstaller::report {ymlDict rawParamDict} {
  set hadoopHome [getHadoopHome $ymlDict]
  ::CommonUtil::spawnCommand [getBinCmd $hadoopHome hdfs] dfsadmin -report
}

proc ::HadoopInstaller::copyLibs {ymlDict rawParamDict} {
  set hadoopHome [getHadoopHome $ymlDict]
  set runFolder [dict get $::rawParamDict runFolder]
  set libs [file join $::baseDir $runFolder libs]
  if {[file exists $libs]} {
    foreach libf [glob -directory $libs  -type f *.jar] {
      exec cp $libf [file join $hadoopHome share hadoop common lib]
    }
  }
}
