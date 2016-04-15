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
				exp_send [lindex $sqls $count]
				incr count
				exp_continue
			}
		}
		eof {}
		timeout {}
	}
}
