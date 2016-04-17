package provide SqlRunner 1.0
package require Expect

namespace eval ::SqlRunner {
}

proc ::SqlRunner::run {sqls password} {
  spawn -noecho mysql -uroot -p

  lappend sqls "exit\r"

	set num [llength $sqls]
  set count 0
  puts "...[llength $sqls]..."
	expect {
		"Enter password: $" {
			exp_send "$password\r"
			exp_continue
		}
		"mysql> $" {
			if {$count < $num} {
        set sq [string trim [lindex $sqls $count]]
        if {[string last \; $sq] == -1} {
          set sq "${sq};"
        }
				exp_send "$sq\r"
				incr count
				exp_continue
			}
		}
		eof {}
		timeout {}
	}
}
