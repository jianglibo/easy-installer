package require tcltest 2.2
eval ::tcltest::configure $::argv

set ::baseDir [file join [file dirname [info script]] ..]
lappend auto_path $::baseDir

package require YamlUtil

namespace eval ::example::test {

    namespace import ::tcltest::*
    testConstraint X [expr {1}]

    variable SETUP {
    }
    variable CLEANUP {}

    test ymerge {} -constraints {X win} -setup $SETUP -body {
      return $::YamlUtil mergeDic
    } -cleanup $CLEANUP -match exact -result {192.168.33.50}

    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
