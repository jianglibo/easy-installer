package provide YamlUtil 1.0
package require yaml
package require CommonUtil

namespace eval ::YamlUtil {
}

proc ::YamlUtil::loadYaml {fn} {
  if {[catch {set dt [::yaml::yaml2dict -file $fn]} msg o]} {
    puts $msg
    ::CommonUtil::endEasyInstall
  } else {
    return $dt
  }
}

proc ::YamlUtil::loadHostYaml {fn ip} {
  set dic [loadYaml $fn]
  if {[dict exists $dic nodes]} {
    set nodes [dict get $dic nodes]
    foreach node $nodes {
      if {! [dict exists $node ip]} {
        puts "node always need an ip property."
        ::CommonUtil::endEasyInstall
      }
      if {[dict get $node ip] eq $ip} {
        return [dict merge $dic $node]
      }
    }
  } else {
    return $dic
  }
}
