package require tcltest 2.2
eval ::tcltest::configure $::argv

set ::baseDir [file join [file dirname [info script]] ..]
lappend auto_path $::baseDir

package require CommonUtil

set ::ymlDict [::CommonUtil::normalizeYmlCfg [::CommonUtil::loadYaml [file join $::baseDir mysql-cluster local-profile.yml]]]

package require confutil

namespace eval ::example::test {

    namespace import ::tcltest::*
    testConstraint X [expr {1}]

    variable SETUP {
    }
    variable CLEANUP {#common cleanup code}

    test get-myroles {} -constraints {X win} -setup $SETUP -body {
      return $::confutil::thisMachineIp
    } -cleanup $CLEANUP -match exact -result {192.168.33.50}

    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
