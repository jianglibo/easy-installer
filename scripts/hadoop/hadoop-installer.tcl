package provide HadoopInstaller 1.0
package require CommonUtil
package require PropertyUtil

namespace eval HadoopInstaller {
  variable installFolder /opt/hadoop
}

proc ::HadoopInstaller::install {ymlDict rawParamDict} {
  variable installFolder

  if {! [file exists $installFolder]} {
    exec mkdir -p $installFolder
  }
  set pwd [pwd]
  set from [dict get $ymlDict DownFrom]
  set fn [lindex [split $from /] end]
  cd $installFolder
  ::CommonUtil::spawnCommand curl -OL $from

  ::CommonUtil::spawnCommand tar -zxf $fn

  cd $pwd

}
