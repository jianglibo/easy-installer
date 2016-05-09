package provide SlaveFirstRun 1.0

package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require Expect
package require SqlRunner

namespace eval ::SlaveFirstRun {
}

#mysql> CHANGE MASTER TO
#    ->     MASTER_HOST='master_host_name',
#    ->     MASTER_USER='replication_user_name',
#    ->     MASTER_PASSWORD='replication_password',
#    ->     MASTER_LOG_FILE='recorded_log_file_name',
#    ->     MASTER_LOG_POS=recorded_log_position;

proc ::SlaveFirstRun::startSlave {ymlDict} {
  set sqls [list]
  set replicaUser [dict get $ymlDict replicaUser]
#  dict for {k v} $replicaUser
  lappend sqls "CHANGE MASTER TO MASTER_HOST='[dict get $replicaUser MasterHost]'"
  lappend sqls "START SLAVE USER='[dict get $replicaUser UserName]' PASSWORD='[dict get $replicaUser Password]'"
  ::SqlRunner::run $sqls [dict get $ymlDict RootPassword]
}


# ----------------------unused code---------------------------
proc ::SlaveFirstRun::getMasterHostRootPassword {} {
  set timeout 10000
  send_user "I need mysql master server's linux box root password to continue. _enter_password:"
  expect_user -re "(.*)\n"
  return $expect_out(1,string)
}


proc ::SlaveFirstRun::getSlaveDbRootPassword {} {
  set timeout 10000
  send_user "I need mysql master server's linux box root password to continue. _enter_password:"
  expect_user -re "(.*)\n"
  return $expect_out(1,string)
}


proc ::SlaveFirstRun::downDump {rawParamDict ymlDict masterPass} {
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
		eof {
      puts "copy dump file done"
    }
		timeout
	}
}

proc ::SlaveFirstRun::run {rawParamDict ymlDict} {
	if {[dict exists $rawParamDict MasterHost]} {
		exec systemctl stop mysqld
		set pidFile /var/run/mysqld/mysqld.pid
    if {! [::AppDetecter::isRunning mysqld]} {
      exec /usr/sbin/mysqld -u mysql --daemonize --skip-slave-start --pid-file=$pidFile >& skip-slave-start.log
    }
		# download dump.db from server.
		downDump $rawParamDict $ymlDict [getMasterHostRootPassword]
		set dumpFile [file tail [dict get $ymlDict DumpFileOnMaster]]

    set slavemp [getSlaveDbRootPassword]

		spawn mysql -uroot -p < $dumpFile
    expect {
      "Enter password: $" {
        exp_send "$slavemp\r"
      }
      eof {
        puts "\nimport dump done."
      }
    }

		::AppDetecter::killByName mysqld
		file delete $pidFile
		exec systemctl start mysqld
	} else {
		puts "--MasterHost parameter is mandatory for this action."
		::CommonUtil::endEasyInstall
	}
}
