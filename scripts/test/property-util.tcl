package require tcltest 2.2
eval ::tcltest::configure $::argv

set ::baseDir [file join [file dirname [info script]] ..]
lappend auto_path $::baseDir

package require PropertyUtil

namespace eval ::example::test {
    proc ::example::test::mmm {line matcher} {
      return [string match $matcher $line]
    }

    namespace import ::tcltest::*
    testConstraint X [expr {1}]

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

    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
