package provide confutil 1.0
package require CommonUtil

namespace eval ::confutil {
  set ips [list]
  dict for {k nodeCfg} $::ymlDict {
    if {[dict exists $nodeCfg nodes]} {
      foreach node [dict get $nodeCfg nodes] {
        lappend ips [dict get $node HostName]
      }
    }
  }
  variable clusterIps [lsort -unique $ips]

  if {$::tcl_platform(platform) eq {windows}} {
    set thisMachineIps {192.168.33.50 10.0.2.15 127.0.0.1}
  } else {
    set thisMachineIps [list]
    set ipaddr [exec ip addr]
    foreach line [split $ipaddr \n] {
      set mt {}
      set ip {}
      regexp {inet\s+(\d+\.\d+\.\d+\.\d+)} $line mt ip
      if {[string length $ip] > 0} {
        lappend thisMachineIps $ip
      }
    }
  }

  variable thisMachineIp {}

  foreach ip $thisMachineIps {
    if {[lsearch -exact $clusterIps $ip] != -1} {
        variable thisMachineIp $ip
    }
  }

  if {[string length $thisMachineIp] == 0} {
    puts stderr "couldn't detect machie ip!"
    exit 1
  }
}

proc ::confutil::getNodeId {role} {
  variable thisMachineIp
  set segd [dict get $::ymlDict $role]
  if {[dict exists $segd nodes]} {
    # we only get one nodid.
    foreach n [dict get $segd nodes] {
      if {[dict get $n HostName] eq $thisMachineIp} {
        return [dict get $n NodeId]
      }
    }
  }
}

proc ::confutil::getNodeIds {role} {
  variable thisMachineIp
  set segd [dict get $::ymlDict $role]
  set nodeids [list]
  if {[dict exists $segd nodes]} {
    foreach n [dict get $segd nodes] {
      if {[dict get $n HostName] eq $thisMachineIp} {
        lappend nodeids [dict get $n NodeId]
      }
    }
  }
  return $nodeids
}

proc ::confutil::getNodeYml {role} {
  variable thisMachineIp
  set segd [dict get $::ymlDict $role]
  if {[dict exists $segd nodes]} {
    # we only get one nodid.
    foreach n [dict get $segd nodes] {
      if {[dict get $n HostName] eq $thisMachineIp} {
        return $n
      }
    }
  }
}

proc ::confutil::getNodeYmls {role} {
  variable thisMachineIp
  set segd [dict get $::ymlDict $role]
  set nodeYmls [list]
  if {[dict exists $segd nodes]} {
    foreach n [dict get $segd nodes] {
      if {[dict get $n HostName] eq $thisMachineIp} {
        lappend nodeYmls $n
      }
    }
  }
  return $nodeYmls
}

proc ::confutil::getMyRoles {} {
  variable thisMachineIp

  set nodeDict [dict create]

  foreach role {NDB_MGMD NDBD MYSQLD} {
    dict set nodeDict $role [dict get $::ymlDict $role nodes]
  }

#  dict set nodeDict API [dict get $::ymlDict API]

  set mr [list]

  dict for {k nodes} $nodeDict {
    foreach n $nodes {
      if {[dict get $n HostName] eq $thisMachineIp} {
        lappend mr $k
      }
    }
  }
  return $mr
}
