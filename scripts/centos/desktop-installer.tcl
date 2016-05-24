package provide DesktopInstaller 1.0

package require CommonUtil
package require OsUtil

namespace eval ::DesktopInstaller {
}

proc ::DesktopInstaller::install {ymlDict rawParamDict} {
  set appFolderBase [dict get $ymlDict BigestDisk]
  if {! [file exists $appFolderBase]} {
    exec mkdir -p $appFolderBase
  }

  ::CommonUtil::spawnCommand yum groupinstall -y "Development Tools"
  ::CommonUtil::spawnCommand yum -y groups install "GNOME Desktop"
  ::CommonUtil::spawnCommand yum install -y git
  ::CommonUtil::spawnCommand yum install -y gunzip
  ::CommonUtil::spawnCommand ln -sf /lib/systemd/system/runlevel5.target /etc/systemd/system/default.target
}

proc ::DesktopInstaller::installApp {appName ymlDict} {
  set appFolderBase [dict get $ymlDict BigestDisk]
  set appDic [dict get $ymlDict downloads $appName]
  set downFrom [dict get $appDic url]
  set extractor [dict get $appDic extractor]

  set curDir [file join $appFolderBase $appName]

  if {! [file exists $curDir]} {
    exec mkdir -p $curDir
  }

  cd $curDir

  ::CommonUtil::downloadIfNeeded $downFrom $extractor

  set extracted [::CommonUtil::getOnlyFolder $curDir]

  set binFolder [file normalize [file join $extracted [dict get $appDic binFolder]]]

  ::CommonUtil::writeLines [file join /etc/profile.d "${appName}.sh"] [list "export PATH=\$PATH:$binFolder"]
}

proc ::DesktopInstaller::vncserver {ymlDict rawParamDict} {
  ::CommonUtil::spawnCommand yum install -y tigervnc-server
  ::OsUtil::openFirewall tcp 5901
  puts "install successly. please login to system, and invoke vncserver."
}

proc ::DesktopInstaller::hadoopPseudo {appName ymlDict} {
  set appFolderBase [dict get $ymlDict BigestDisk]
  set appDic [dict get $ymlDict downloads $appName]
  set downFrom [dict get $appDic url]
  set extractor [dict get $appDic extractor]

  set curDir [file join $appFolderBase $appName]

  if {! [file exists $curDir]} {
    exec mkdir -p $curDir
  }
  cd $curDir

  ::CommonUtil::downloadIfNeeded $downFrom $extractor

  set extracted [::CommonUtil::getOnlyFolder $curDir]
  set hadoopCfgFolder [file join $extracted etc hadoop]

  ::CommonUtil::write [file join $hadoopCfgFolder core-site.xml] {<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
      <name>fs.defaultFS</name>
      <value>hdfs://localhost:9000</value>
  </property>
</configuration>
  }
  ::CommonUtil::write [file join $hadoopCfgFolder hdfs-site.xml] {<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>
}
  ::CommonUtil::write [file join $hadoopCfgFolder mapred-site.xml] {<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>
  }

  ::CommonUtil::write [file join $hadoopCfgFolder yarn-site.xml] {<?xml version="1.0"?>
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
}

#bin/hdfs namenode -format
#sbin/start-dfs.sh
#sbin/start-yarn.sh
#sbin/stop-yarn.sh
  puts $extracted
}

proc ::DesktopInstaller::hbase {appName ymlDict} {
  set appFolderBase [dict get $ymlDict BigestDisk]
  set appDic [dict get $ymlDict downloads $appName]
  set downFrom [dict get $appDic url]
  set extractor [dict get $appDic extractor]

  set curDir [file join $appFolderBase $appName]

  if {! [file exists $curDir]} {
    exec mkdir -p $curDir
  }
  cd $curDir

  ::CommonUtil::downloadIfNeeded $downFrom $extractor

  set extracted [::CommonUtil::getOnlyFolder $curDir]
  set hbaseCfgFolder [file join $extracted conf]
  set c {<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>%s</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>%s</value>
  </property>
</configuration>
  }

  ::CommonUtil::write [file join $hbaseCfgFolder hbase-site.xml] [format $c [dict get $appDic hbase.rootdir] [dict get $appDic hbase.zookeeper.property.dataDir]]

#bin/start-hbase.sh
  puts $extracted

}
