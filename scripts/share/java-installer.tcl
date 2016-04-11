package provide JavaInstaller 1.0
package require AppDetecter

namespace eval JavaInstaller {
}


proc ::JavaInstaller::install {} {
	if {[::AppDetecter::isInstalled java]} {
		puts stdout "java already installed, skip installing."
	} else {
		set javaFolder [dict get $::ymlDict JavaFolder]
		set jdkFile [dict get $::ymlDict TarFile]
		set jdkFolder [dict get $::ymlDict ExtractFolder]
		set fileHost [dict get $::ymlDict ServeHost]

		if {! [file exists $javaFolder]} {
			exec mkdir -p $javaFolder
		}

		cd $javaFolder

		if {! [file exists $javaFolder/$jdkFile]} {
			puts stdout "start downloading $fileHost/$jdkFile....\n"
			exec curl -O $fileHost/$jdkFile >&  curloutput.log
			puts stdout "download finished.\n"
		}

		if {! [file exists $javaFolder/$jdkFile]} {
			puts stdout "download $javaFolder/$jdkFile failed."
			exit 2
		}

		if {[file size $javaFolder/$jdkFile] < 10000} {
			puts stdout "download $javaFolder/$jdkFile failed.deleting partial file..."
			file delete $javaFolder/$jdkFile
			exit 2
		}

		exec tar -zxf $jdkFile

		exec alternatives --install "/usr/bin/java" "java" "$javaFolder/$jdkFolder/bin/java" 1
		exec alternatives --install "/usr/bin/javac" "javac" "$javaFolder/$jdkFolder/bin/javac" 1
		exec alternatives --install "/usr/bin/jar" "jar" "$javaFolder/$jdkFolder/bin/jar" 1
		exec alternatives --install "/usr/bin/javah" "javah" "$javaFolder/$jdkFolder/bin/javah" 1
		exec alternatives --install "/usr/bin/javadoc" "javadoc" "$javaFolder/$jdkFolder/bin/javadoc" 1

		puts stdout "checking java install..."

		if { [catch {puts [exec java -version 2>@1]} msg] } {
			puts stdout "java install failed!"
			exit 2
		}
	}
}
