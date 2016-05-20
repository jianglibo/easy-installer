package provide JavaInstaller 1.0
package require AppDetecter
package require CommonUtil
package require OsUtil

namespace eval JavaInstaller {
	variable profiled /etc/profile.d/myjava.sh
}

proc ::JavaInstaller::install {} {
	variable profiled
	if {! [::AppDetecter::isInstalled java]} {
		set DstFolder [dict get $::ymlDict DstFolder]
		set DownFrom [dict get $::ymlDict DownFrom]

		set jdkFile [lindex [split $DownFrom /] end]

		if {! [file exists $DstFolder]} {
			exec mkdir -p $DstFolder
		}

		cd $DstFolder

		if {! [file exists $DstFolder/$jdkFile]} {
			::CommonUtil::spawnCommand curl -O $DownFrom
#			 >&  curloutput.log
		}

		if {! [file exists $DstFolder/$jdkFile]} {
			puts stdout "download $DstFolder/$jdkFile failed."
			::CommonUtil::endEasyInstall
		}

		if {[file size $DstFolder/$jdkFile] < 10000} {
			puts stdout "download $DstFolder/$jdkFile failed.  deleting partial file..."
			file delete $DstFolder/$jdkFile
			::CommonUtil::endEasyInstall
		}


		if {[catch {exec tar -zxf $jdkFile} msg o]} {
			::CommonUtil::spawnCommand rm -rvf $jdkFile
			::CommonUtil::endEasyInstall
		}

		set binFolder [file dirname [lindex [split [exec find $DstFolder -name javah] \n] 0]]

		foreach jexec {java javac jar javah javadoc jps} {
			exec alternatives --install "/usr/bin/$jexec" "$jexec" [file join $binFolder $jexec] 1
		}

		puts stdout "checking java install..."

		if { [catch {puts [exec java -version 2>@1]} msg] } {
			puts stdout "java install failed!"
			::CommonUtil::endEasyInstall
		}
	}

	set lines [list]
	lappend lines "JAVA_HOME=[::OsUtil::getAppHome java .. ..]"
	lappend lines "export JAVA_HOME"
	::OsUtil::writeProfiled $profiled $lines
	puts stdout "java already installed, skip installing."
}
