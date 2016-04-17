package require tcltest 2.2
eval ::tcltest::configure $::argv

#regexp ?switches? exp string ?matchVar? ?subMatchVar subMatchVar ...?

namespace eval ::example::test {
    namespace import ::tcltest::*
    testConstraint X [expr {1}]

    variable SETUP {

    }
    variable CLEANUP {#common cleanup code}

    test line-processor {} -constraints X -setup $SETUP -body {
      set scripts {
        if {[string first a $line]} {
          lappend result $line
        }
      }
      set lines {ab cd ad}
      set result [list]

      foreach line $lines {
        eval $scripts
      }
      return $result
   } -cleanup $CLEANUP -match exact -result {cd}

    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
