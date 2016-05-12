package provide DnsmasqInstaller 1.0
package require CommonUtil
package require PropertyUtil

namespace eval DnsmasqInstaller {
}

proc ::DnsmasqInstaller::install {ymlDict rawParamDict} {
  if {! [::CommonUtil::sysInstalled dnsmasq.service]} {
    ::CommonUtil::spawnCommand yum install -y dnsmasq dnsmasq-utils
    exec systemctl enable dnsmasq.service
    exec systemctl start dnsmasq
  }
  ::PropertyUtil::changeOrAdd /etc/dnsmasq.conf [dict get $ymlDict dnsmasqCnf]
  updateHosts $ymlDict
  exec systemctl restart dnsmasq
}

proc ::DnsmasqInstaller::updateHosts {ymlDict} {
  set dnsmasqCnf [dict get $ymlDict dnsmasqCnf addn-hosts]
  if {[catch {open $dnsmasqCnf w} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    dict for {k v} [dict get $ymlDict etchosts] {
      puts $fid "$v $k"
    }
    close $fid
  }
}
