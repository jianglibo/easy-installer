package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require SecureMe
package require Expect
package require AddUser
package require SlaveFirstRun
package require Mirror

proc checkSlaveRequirement {ymlDict} {
  if {[dict get $ymlDict Master]} {
    puts "the 'Master' value in [dict get $::rawParamDict profile] is 1.It is a profile for master server."
    ::CommonUtil::endEasyInstall
  }
  if {[string match *master* [dict get $ymlDict mycnf]]} {
    puts "mycnf item in [dict get $::rawParamDict profile] contains 'master'!!"
    ::CommonUtil::endEasyInstall
  }
}

proc checkMasterRequirement {ymlDict} {
  if {! [dict get $ymlDict Master]} {
    puts "the 'Master' value in [dict get $::rawParamDict profile] is 0.It is a profile for repliaction server."
    ::CommonUtil::endEasyInstall
  }
}

catch {
  set action [dict get $::rawParamDict action]

  if {! ([dict get $::rawParamDict host] eq [dict get $::ymlDict hostIp])} {
    puts "parameter host value is [dict get $::rawParamDict host], but yml profile hostIp is [dict get $::ymlDict hostIp] !!!!"
    ::CommonUtil::endEasyInstall
  }
  switch $action {
  	install {
      checkMasterRequirement $::ymlDict
  		::MysqlInstaller::install $::ymlDict $::rawParamDict
      ::SecureMe::doSecure $::ymlDict $::rawParamDict
      ::AddUser::add $::rawParamDict $::ymlDict
      ::AddUser::addReplica $::rawParamDict $::ymlDict
  	}
    installOnly {
      checkMasterRequirement $::ymlDict
      ::MysqlInstaller::install $::ymlDict $::rawParamDict
    }
    secureOnly {
      checkMasterRequirement $::ymlDict
      ::SecureMe::doSecure $::ymlDict $::rawParamDict
    }
    installSlave {
      checkSlaveRequirement $::ymlDict
      ::MysqlInstaller::install $::ymlDict $::rawParamDict
      ::SecureMe::doSecure $::ymlDict $::rawParamDict
      ::SlaveFirstRun::startSlave $::ymlDict
    }
    startSlave {
      checkSlaveRequirement $::ymlDict
      ::SlaveFirstRun::startSlave $::ymlDict
    }
    secureMe {
      ::SecureMe::doSecure $::ymlDict $::rawParamDict
    }
    mirror {
      ::Mirror::mirror $::rawParamDict
    }
    updateUser {
      ::AddUser::add $::rawParamDict $::ymlDict
      ::AddUser::addReplica $::rawParamDict $::ymlDict
    }
  	dump {
      set rpass [acquireDbRootPassword]
      set replStarter [file join [file dirname [dict get $::ymlDict datadir]] forMysqlReplica]
      if {! [file exists $replStarter]} {
        exec mkdir -p $replStarter
      }
			set replDumpFile [file join $replStarter dump.db]
      puts "\nstart execute mysqldump\n"
      [exec mysqldump -uroot -p$rpass -h localhost --all-databases --master-data > $replDumpFile]
  	}
    default {
      puts "\n******unrecoganized action: $action , please check again.******\n"
    }
  }
} msg o

if {[dict get $o -code] > 0} {
  puts $msg
}

::CommonUtil::endEasyInstall

if {0} {
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
}
