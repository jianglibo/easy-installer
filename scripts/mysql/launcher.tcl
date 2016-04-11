package require AppDetecter
package require CommonUtil

if {! [dict exists $::rawParamDict profile]} {
  puts stderr "parameter --profile doesn't exists!"
  exit 1
}

set cfgFile [file join $::baseDir mysql [dict get $::rawParamDict profile]]

if {! [string match *.yml $cfgFile]} {
  set cfgFile "$cfgFile.yml"
}

set ::ymlDict [::CommonUtil::loadYaml $cfgFile]

set allIps [list]

lappend allIps [dict get $::ymlDict MASTER HostName]

foreach slv [dict get $::ymlDict SLAVES] {
	lappend allIps [dict get $slv HostName]
}

if {[string length [::CommonUtil::getThisMachineIp $allIps]] == 0} {
	puts stdout "target machie ip not in $cfgFile"
	exit 1
}

package require MysqlInstaller
package require MysqlInit


set action [dict get $::rawParamDict action]
puts "$action........................................."

switch $action {
	install {
		::MysqlInstaller::install
	}
  init {
    ::MysqlInit::init
  }
}
