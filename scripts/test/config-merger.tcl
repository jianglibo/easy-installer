package require tcltest 2.2
eval ::tcltest::configure $::argv

#regexp ?switches? exp string ?matchVar? ?subMatchVar subMatchVar ...?

namespace eval ::example::test {
    namespace import ::tcltest::*
    testConstraint X [expr {1}]

    variable SETUP {

    }
    variable CLEANUP {#common cleanup code}

    test is-right? {} -constraints X -setup $SETUP -body {
      
    } -cleanup $CLEANUP -match exact -result {aab}

    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
