package provide MysqlClusterInstaller 1.0

package require AppDetecter

namespace eval ::MysqlClusterInstaller {
}

#http://dev.mysql.com/get/Downloads/MySQL-Cluster-7.4

proc ::MysqlClusterInstaller::install {tmpFolder} {

	if {[::AppDetecter::isInstalled ndb_mgmd]} {
	  puts stderr "******mysql cluster already installed.******"
		exit 0
	}

	if {! [file exists $tmpFolder]} {
		puts stdout "start make $tmpFolder ..."
		exec mkdir -p $tmpFolder
		puts stdout "mkdir $tmpFolder done."
	}

	cd $tmpFolder

	set rs [lindex [split [dict get $::ymlDict DownFrom] /] end]

	if {! [file exists $rs]} {
		puts stdout "start downloading $::ymlDict"
		exec curl -OL [dict get $::ymlDict DownFrom] >& curloptout.log
		puts stdout "downloading done."
		puts stdout "extracting $rs"
		exec tar -xvf $rs
		puts stdout "exact done."
	}

#	catch {[exec yum install -y python-paramiko]} msg
#	puts stdout $msg

	foreach f [glob MySQL*.rpm] {
		catch {[exec yum -y remove mysql-libs]} msg
		if {[string match *-server-gpl-* $f] || [string match *-client-gpl-* $f]} {
			puts stdout "start install $f..."
			catch {[exec yum localinstall -y $f]} msg
			puts stdout $msg
			} else {
				puts stdout "skipping $f"
			}
		}
}
