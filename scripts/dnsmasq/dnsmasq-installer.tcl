package provide DnsmasqInstaller 1.0
package require CommonUtil
package require PropertyUtil

namespace eval DnsmasqInstaller {
}

proc ::DnsmasqInstaller::install {ymlDict rawParamDict} {
  ::CommonUtil::spawnCommand yum install -y dnsmasq dnsmasq-utils
  exec systemctl enable dnsmasq.service
  exec systemctl start dnsmasq
  ::PropertyUtil::changeOrAdd /etc/dnsmasq.conf $ymlDict
}
