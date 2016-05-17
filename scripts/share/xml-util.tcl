package provide XmlUtil 1.0
package require CommonUtil

namespace eval ::XmlUtil {
}

proc ::XmlUtil::getPropertyValue {fileName pname} {
  set content [::CommonUtil::readWholeFile $fileName]
  if {[regexp [format {<property>(.*?)<name>\s*%s\s*</name>(.*?)</property>} $pname] $t mh m1 m2]} {
    if {[regexp {<value>(.*?)</value>} $m1 mmh mm1]} {
      return [string trim $mm1]
    } else if {[regexp {<value>(.*?)</value>} $m2 mmh mm1]} {
      return [string trim $mm1]
    } else {
      return {}
    }
  } else {
    return {}
  }
}
