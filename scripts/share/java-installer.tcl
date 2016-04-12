package provide JavaInstaller 1.0
package require AppDetecter

namespace eval JavaInstaller {
}

proc ::JavaInstaller::install {} {
	if {[::AppDetecter::isInstalled java]} {
		puts stdout "java already installed, skip installing."
	} else {
		set DstFolder [dict get $::ymlDict DstFolder]
		set DownFrom [dict get $::ymlDict DownFrom]

		set jdkFile [lindex [split $DownFrom /] end]

		if {! [file exists $DstFolder]} {
			exec mkdir -p $DstFolder
		}

		cd $DstFolder

		if {! [file exists $DstFolder/$jdkFile]} {
			puts stdout "start downloading $DownFrom....\n"
			exec curl -O $DownFrom >&  curloutput.log
			puts stdout "download finished.\n"
		}

		if {! [file exists $DstFolder/$jdkFile]} {
			puts stdout "download $DstFolder/$jdkFile failed."
			exit 2
		}

		if {[file size $DstFolder/$jdkFile] < 10000} {
			puts stdout "download $DstFolder/$jdkFile failed.  deleting partial file..."
			file delete $DstFolder/$jdkFile
			exit 2
		}

		exec tar -zxf $jdkFile
		set binFolder [file dirname [lindex [split [exec find $DstFolder -name javah] \n] 0]]

		foreach jexec {java javac jar javah javadoc} {
			exec alternatives --install "/usr/bin/$jexec" "$jexec" [file join $binFolder $jexec] 1
		}

		puts stdout "checking java install..."

		if { [catch {puts [exec java -version 2>@1]} msg] } {
			puts stdout "java install failed!"
			exit 2
		}
	}
}
