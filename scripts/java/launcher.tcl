package require JavaInstaller

::JavaInstaller::install

set fileHostExists [dict exists $::rawParamDict fileHost]
set jdkFileExists [dict exists $::rawParamDict jdkFile]

if {$fileHostExists} {
	set fileHost [dict get $::rawParamDict fileHost]
}
