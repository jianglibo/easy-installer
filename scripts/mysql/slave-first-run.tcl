package provide SlaveFirstRun 1.0

package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require Expect
package require SqlRunner

namespace eval ::SlaveFirstRun {
}

proc ::SlaveFirstRun::getMasterHostRootPassword {} {
  send_user "I need mysql master server's linux box root password to continue. _enter_password:"
  expect_user -re "(.*)\n"
  return $expect_out(1,string)
}

proc ::SlaveFirstRun::downDump {paramsDict ymlDict masterPass} {
	set dfonmaster [dict get $ymlDict DumpFileOnMaster]
	set remoteDump "root@[dict get $rawParamDict MasterHost]:$dfonmaster"
	spawn scp $remoteDump .
	expect {
		"Are you sure you want to continue connecting (yes/no)? $" {
			exp_send "yes\r"
			exp_continue
		}
		"'s password: $" {
			exp_send "$masterPass\r"
		}
		eof {}
		timeout
	}
}

proc ::SlaveFirstRun::run {paramsDict ymlDict} {
	if {[dict exists $rawParamDict MasterHost]} {
		exec systemctl stop mysqld
		set pidFile /var/run/mysqld/mysqld.pid
		exec /usr/sbin/mysqld -u mysql --daemonize --skip-slave-start --pid-file=$pidFile >& skip-slave-start.log
		# download dump.db from server.
		downDump $paramsDict $ymlDict [getMasterHostRootPassword]
		set dumpFile [file tail [dict get $ymlDict DumpFileOnMaster]]
		exec mysql -uroot -p < $dumpFile
		::AppDetecter::killByName mysqld
		file delete $pidFile
		exec systemctl start mysqld
	} else {
		puts "--MasterHost parameter is mandatory for this action."
		::CommonUtil::endEasyInstall
	}
}
