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

  if {[catch {exec tar -zxf $fn} msg o]} {
    dict for {k v} $o {
      puts "$k=$v"
    }

    puts "$fn is damaged. please try again."
    exec rm -f $fn
    if {[regexp {(.*)\.tar\.gz$} $fn mh m1]} {
      exec rm -rf $m1
    }
    ::CommonUtil::endEasyInstall
  }
  cd $pwd
}
