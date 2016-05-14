package provide YamlUtil 1.0
package require yaml
package require CommonUtil

namespace eval ::YamlUtil {
}

proc ::YamlUtil::loadYaml {fileName} {
  if {[catch {set dt [::yaml::yaml2dict -file $fileName]} msg o]} {
    puts $msg
    ::CommonUtil::endEasyInstall
  } else {
    return $dt
  }
}

proc ::YamlUtil::getHostYmlNodes {dic rawParamDict} {
  set myNodes [list]
  if {! [dict exists $dic nodes]} {
    return $myNodes
  }
  set nodes [dict get $dic nodes]
  set ip [dict get $rawParamDict host]

  foreach node $nodes {
    if {[dict get $node ip] eq $ip} {
      lappend myNodes $node
    }
  }
  return $myNodes
}

proc ::YamlUtil::findValue {ymlDict key rawParamDict} {
  if {[dict exists $ymlDict $key]} {
    return [dict get $ymlDict $key]
  }
  set myNodes [getHostYmlNodes $ymlDict $rawParamDict]
  foreach node $myNodes {
    if {[dict exists $node $key]} {
      return [dict get $node $key]
    }
  }
  return {}
}
