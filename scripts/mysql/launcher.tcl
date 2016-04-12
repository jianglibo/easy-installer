package require AppDetecter
package require CommonUtil


proc getBoxConfig {} {
	set allIps [list]

	set MASTER [dict get $::ymlDict MASTER]

	lappend allIps [dict get $MASTER HostName]

	foreach slv [dict get $::ymlDict SLAVES] {
		lappend allIps [dict get $slv HostName]
	}

	set thisMachineIp [::CommonUtil::getThisMachineIp $allIps]

	if {[string length $thisMachineIp] == 0} {
		puts stdout "target machie ip not in $cfgFile"
		exit 1
	}

	if {[string equal $thisMachineIp [dict get $MASTER HostName]]} {
		return [list 1 $MASTER]
	} else {
		foreach slvn [dict get $::ymlDict SLAVES] {
			if {[string equal $thisMachineIp [dict get $slvn HostName]]} {
				return [list 0 [dict merge $MASTER $slvn]]
			}
		}
	}
}

package require MysqlInstaller
package require MysqlInit


set action [dict get $::rawParamDict action]

switch $action {
	install {
		::MysqlInstaller::install {*}[getBoxConfig]
	}
  init {
    ::MysqlInit::init
  }
}
