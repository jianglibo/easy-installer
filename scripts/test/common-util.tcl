package require tcltest 2.2
eval ::tcltest::configure $::argv

set ::baseDir [file join [file dirname [info script]] ..]
lappend auto_path $::baseDir

package require CommonUtil

namespace eval ::example::test {

    proc ::example::test::mmm {line matcher} {
      return [string match $matcher $line]
    }

    namespace import ::tcltest::*
    testConstraint X [expr {1}]

    variable lines [split {# management server host (default port is 1186)
[mysqld]
ndbcluster
ndb-connectstring=nodeid=50,192.168.33.50:14500
# provide connection string for management server host (default port: 1186)
[ndbd]
connect-string=nodeid=50,192.168.33.50:14500} \n]

    variable SETUP {
    }
    variable CLEANUP {#common cleanup code}

    test example-2 {} -constraints X -setup $SETUP -body {
      set segs [::CommonUtil::splitSeg $lines {\[*]}]
      set l [list]
      dict for {k v} $segs {
        lappend l $k
        lappend l [llength $v]
      }
      return $l
    # Second test; constrained
    } -cleanup $CLEANUP -match exact -result {{[mysqld]} 5 {[ndbd]} 2}

    test yml-normalize {} -constraints X -setup $SETUP -body {
      set normalized [::CommonUtil::loadNormalizedYmlDic [file join $::baseDir mysql-cluster local-profile.yml]]

      dict get [lindex [dict get $normalized MYSQLD nodes] 0] DataDir
    # Second test; constrained
    } -cleanup $CLEANUP -match exact -result {/opt/mysql-cluster-mysqld/100}

    test getMgmHosts {} -constraints X -setup $SETUP -body {
      set ::ymlDict [::CommonUtil::normalizeYmlCfg [::CommonUtil::loadYaml [file join $::baseDir mysql-cluster local-profile.yml]]]
      return [::CommonUtil::getMgmHosts $ymlDict]
    # Second test; constrained
    } -cleanup $CLEANUP -match exact -result {192.168.33.50:41500 192.168.33.51:41500}

    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
