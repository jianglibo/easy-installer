package require AppDetecter
package require CommonUtil

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
