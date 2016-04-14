package require tcltest 2.2
eval ::tcltest::configure $::argv

#regexp ?switches? exp string ?matchVar? ?subMatchVar subMatchVar ...?

namespace eval ::example::test {
    namespace import ::tcltest::*
    testConstraint X [expr {1}]

    variable SETUP {}
    variable CLEANUP {#common cleanup code}

    test should-get-position {} -constraints X -setup $SETUP -body {
    set result  {show master status;
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000002 |     4952 |              |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
1 row in set (0.00 sec)

mysql>}
      regexp {.*\|\s+(mysql-bin.*?[^ ]+)\s+\|\s+(\d+)\s+\|.*} $result m lf pos
      return $pos
    } -cleanup $CLEANUP -match exact -result {4952}
    # match regexp, glob, exact
    cleanupTests
}
namespace delete ::example::test
