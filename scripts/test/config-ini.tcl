package require tcltest 2.2
eval ::tcltest::configure $::argv

set ::baseDir [file join [file dirname [info script]] ..]

lappend auto_path $::baseDir

package require CommonUtil
package require confini

namespace eval ::example::test {
    set ::ymlDict [::CommonUtil::normalizeYmlCfg [::CommonUtil::loadYaml [file join $::baseDir mysql-cluster local-profile.yml]]]

    namespace import ::tcltest::*
    testConstraint X [expr {1}]

    variable SETUP {

    }
    variable CLEANUP {#common cleanup code}

    test has-split-to-dict {} -constraints X -setup $SETUP -body {
      return [dict keys $::confini::iniDic]
    } -cleanup $CLEANUP -match exact -result {{[NDB_MGMD DEFAULT]} {[NDB_MGMD]} {[NDBD DEFAULT]} {[NDBD]} {[MYSQLD DEFAULT]} {[MYSQLD]}}

    test before-substituted-content {} -constraints X -setup $SETUP -body {
      set ll [list]
      dict for {k v} $::confini::iniDic {
        lappend ll [llength $v]
      }
      return $ll
    } -cleanup $CLEANUP -match exact -result {8 6 32 7 4 14}

    ::confini::substitute

    test has-substituted {} -constraints X -setup $SETUP -body {
      return [dict keys $::confini::iniDic]
    } -cleanup $CLEANUP -match exact -result {{[NDB_MGMD DEFAULT]} {[NDB_MGMD]} {[NDBD DEFAULT]} {[NDBD]} {[MYSQLD DEFAULT]} {[MYSQLD]}}

    test after-substituted-content {} -constraints X -setup $SETUP -body {
      set ll [list]
      dict for {k v} $::confini::iniDic {
        lappend ll [llength $v]
      }
      return $ll
    } -cleanup $CLEANUP -match exact -result {8 12 32 14 4 56}

    ::confini::writeToDisk [file join $::baseDir test fixturesout config.ini]

    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
