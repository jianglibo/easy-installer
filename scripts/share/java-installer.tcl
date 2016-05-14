package provide JavaInstaller 1.0
package require AppDetecter
package require CommonUtil

namespace eval JavaInstaller {
}

proc ::JavaInstaller::install {} {
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
	puts stdout "java already installed, skip installing."
}
