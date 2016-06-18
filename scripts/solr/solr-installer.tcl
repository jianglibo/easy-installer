package provide SolrInstaller 1.0
package require CommonUtil

namespace eval SolrInstaller {
}

proc ::SolrInstaller::getSolrHome {ymlDict} {
  set installFolder [dict get $ymlDict DstFolder]

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

proc ::SolrInstaller::install {ymlDict rawParamDict} {
  set solrHome [getSolrHome $ymlDict]
}
