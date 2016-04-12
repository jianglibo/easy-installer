package provide ConfigMerger 1.0

namespace eval ::ConfigMerger {

}

proc ::ConfigMerger::merge {rawParamDict ymlDict} {
  dict for {k v} $rawParamDict {
      set ks [split $k .]
      if {[dict exists $ymlDict {*}$ks]} {
        dict set ymlDict {*}$ks $v
      }
  }
  return $ymlDict
}
