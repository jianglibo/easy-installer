package require tcltest 2.2
eval ::tcltest::configure $::argv

namespace eval ::example::test {
    namespace import ::tcltest::*
    testConstraint X [expr {1}]

    variable SETUP {

    }
    variable CLEANUP {#common cleanup code}

    test catch-in-if {} -constraints X -setup $SETUP -body {
      if {[catch {
          exec mkdir /opt/yyy/xx
        } msg o]} {
        return 1
      } else {
        return 0
      }
    } -cleanup $CLEANUP -match exact -result {1}

    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
