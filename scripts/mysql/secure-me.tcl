package provide SecureMe 1.0
package require CommonUtil
package require Expect
package require PropertyUtil
package require SecureUtil

namespace eval ::SecureMe {
}

# when first start, bin-log not enabled.


proc ::SecureMe::doSecure {ymlDict rawParamDict} {

  if {[::CommonUtil::sysRunning mysqld]} {
    puts "stopping mysqld..................."
     ::CommonUtil::spawnCommand systemctl stop mysqld
  }

  set mycnf [file join $::baseDir [dict get $rawParamDict {runFolder}] [dict get $ymlDict {mycnf}]]

  ::CommonUtil::replaceFileContentInLine $mycnf $ymlDict

  set propertiesDict [::PropertyUtil::properties2dict $mycnf]

	set mysqlLog [dict get $propertiesDict log-error]

	# mysql not initialized
  #	if {(! [file exists $mysqlLog]) || ([file size $mysqlLog] < 10)} {

  if {! [file exists /etc/my.cnf.origin]} {
    exec mv /etc/my.cnf /etc/my.cnf.origin
  }

  exec cp $mycnf /etc/my.cnf

  set toCommentOut [dict get $ymlDict commentOut]

  ::PropertyUtil::commentLines /etc/my.cnf $toCommentOut

	::CommonUtil::spawnCommand systemctl start mysqld

	if {[catch {open $mysqlLog} fid o]} {
		puts stdout $fid
		::CommonUtil::endEasyInstall
	} else {
		while {[gets $fid line] >= 0} {
      if {[regexp {.*temporary password.*?:\s*(.*)} $line mh tmppsd]} {
        puts "found temporary password: $tmppsd"
      }
		}
		close $fid
	}

	#if you successly run this code, password should not match. it is harmless.
  SecureUtil::doSecure $tmppsd [dict get $ymlDict RootPassword]

  ::CommonUtil::spawnCommand systemctl stop mysqld
  #now enable log-bin
  ::PropertyUtil::unCommentLines /etc/my.cnf [dict get $ymlDict unCommentOut]
  ::CommonUtil::spawnCommand systemctl start mysqld
}


proc ::SecureMe::enableBinLog {} {
  if {! [dict exists $::rawParamDict server-id]} {
    puts "\nserver-id is mandatory.\n"
    ::CommonUtil::endEasyInstall
  }
  set scripts {
    if {[string first #log-bin= $line] == 0} {
      lappend lines "log-bin=mysql-bin"
    } elseif {[string first #server-id= $line] == 0} {
      lappend lines "server-id=[dict get $::rawParamDict server-id]"
    } elseif {[string first #innodb_flush_log_at_trx_commit= $line] == 0} {
      lappend lines "innodb_flush_log_at_trx_commit=1"
    } elseif {[string first #sync_binlog= $line] == 0} {
      lappend lines "sync_binlog=1"
    } else {
      lappend lines $line
    }
	}
  ::CommonUtil::substFileLineByLine /etc/my.cnf $scripts
  ::CommonUtil::spawnCommand systemctl start mysqld
}
