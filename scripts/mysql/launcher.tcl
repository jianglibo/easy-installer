package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require SecureMe
package require Expect
package require AddUser

proc checkIp {} {
  if {[string length [::CommonUtil::getThisMachineIp [dict get $::ymlDict HostName]]] == 0} {
    puts stdout "machine ip doesn't match HostName item in [dict get $::rawParamDict profile]"
    ::CommonUtil::endEasyInstall
  }
}

if {! [::AppDetecter::isInstalled expect]} {
  puts stdout "expect not installed, start to install...."
  catch {exec yum install -y expect} msg o
}

proc acquireDbRootPassword {} {
  set timeout 1000
  send_user "I need db root password to continue. _enter_password:"
	expect_user -re "(.*)\n"
	set pass $expect_out(1,string)
  spawn mysqladmin ping -p
  expect {
    "Enter password: $" {
      exp_send "$pass\r"
      exp_continue
    }
    "Access denied" {
      ::CommonUtil::endEasyInstall
    }
    "mysqld is alive" {
      return $pass
    }
    timeout {::CommonUtil::endEasyInstall}
  }
}

catch {
  set action [dict get $::rawParamDict action]

  switch $action {
  	install {
  		::MysqlInstaller::install [dict get $::ymlDict IsMaster] $::ymlDict
  	}
    secureInstallation {
      ::SecureMe::doSecure $::ymlDict
    }
    createUser {
      catch {::AddUser::add $::rawParamDict [acquireDbRootPassword]} msg o
      if {[dict get $o -code] > 0} {
        puts $msg
      }
    }
  	dump {
      set rpass [acquireDbRootPassword]
      set replStarter [file join [file dirname [dict get $::ymlDict datadir]] forMysqlReplica]
			set replDumpFile [file join $replStarter dump.db]
      puts "\nstart execute mysqldump\n"
      [exec mysqldump -uroot -p$rpass -h localhost --all-databases --master-data > $replDumpFile]

#      ::FreezeReplca::freeze $::ymlDict
  	}
  }
} msg o

if {[dict get $o -code] > 0} {
  puts $msg
}
::CommonUtil::endEasyInstall
