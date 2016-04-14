package provide FreezeReplca 1.0

package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require Expect
package require Mycnf

namespace eval ::FreezeReplca {
}

# if mysqldump with --master-data, then no need to got position separately.
proc ::FreezeReplca::freeze {ymlDict rpass} {
	set timeout 1000
  set first_id [spawn -noecho mysql -uroot -p]

	set count 0
	expect {
		"Enter password: $" {
			exp_send "$rpass\r"
			exp_continue
		}
		"mysql> $" {
			if {$count == 0} {
				exp_send "FLUSH TABLES WITH READ LOCK;\r"
				incr count
				exp_continue
			} elseif {$count == 1} {
				exp_send "SHOW MASTER STATUS;\r"
				incr count
				exp_continue
			} elseif {$count == 2} {
				set result $expect_out(buffer)
				if {[regexp {.*\|\s+(mysql-bin.*?[^ ]+)\s+\|\s+(\d+)\s+\|.*} $result m lf pos]} {
					set replStarter [file join [file dirname [dict get $ymlDict datadir]] forMysqlReplica]
					set replInfo [file join $replStarter pos.info]
					set replDumpFile [file join $replStarter dump.db]
					if {! [file exists $replStarter]} {
						exec mkdir -p $replStarter
					}
					puts "\nstart execute mysqldump\n"
					catch {[exec mysqldump -uroot -p$rpass -h localhost --all-databases --master-data > $replDumpFile]} msg o

					if {[catch {open $replInfo w} fid o]} {
						puts stdout $fid
					} else {
						puts $fid "File:$lf"
						puts $fid "Position:$pos"
						close $fid
					}
					exp_send "UNLOCK TABLES;\r"
				} else {
					puts stdout "couldn't match position result."
					exp_send "exit\r"
				}
			} else {
				exp_send "exit\r"
			}
		}
		eof {}
		timeout {
			::CommonUtil::endEasyInstall
		}
	}
}
