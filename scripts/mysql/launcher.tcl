package require AppDetecter
package require CommonUtil
package require MysqlInstaller
package require SecureMe
package require Expect
package require AddUser
package require SlaveFirstRun
package require Mirror


catch {
  set action [dict get $::rawParamDict action]

  if {! ([dict get $::rawParamDict host] eq [dict get $::ymlDict hostIp])} {
    puts "parameter host value is [dict get $::rawParamDict host], but yml profile hostIp is [dict get $::ymlDict hostIp] !!!!"
    ::CommonUtil::endEasyInstall
  }
  switch $action {
  	install {
  		::MysqlInstaller::install $::ymlDict $::rawParamDict
      ::SecureMe::doSecure $::ymlDict $::rawParamDict
  	}
    startSlave {
      ::SecureMe::enableBinLog
      ::SlaveFirstRun::startSlave
    }
    mirror {
      ::Mirror::mirror $::rawParamDict
    }
    createUser {
      catch {::AddUser::add $::rawParamDict [acquireDbRootPassword]} msg o
      if {[dict get $o -code] > 0} {
        puts $msg
      }
    }
    createReplicaUser {
      catch {::AddUser::addReplica $::rawParamDict [acquireDbRootPassword]} msg o
      if {[dict get $o -code] > 0} {
        puts $msg
      }
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
