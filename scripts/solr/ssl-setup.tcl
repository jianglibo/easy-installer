package provide SslSetup 1.0
package require OsUtil

namespace eval SslSetup {
}

proc ::SslSetup::setup {ymlDict zkcli oneZkHost} {
  if {[dict get $ymlDict enableSSL]} {
    set keytool [file normalize [file join [::OsUtil::getAppHome java] .. keytool]]
    set sslOptions [dict get $ymlDict sslOptions ini]
    set password [dict get $sslOptions SOLR_SSL_KEY_STORE_PASSWORD]
    set keyStore [dict get $sslOptions SOLR_SSL_KEY_STORE]
    set solrNodes [dict get $ymlDict solrNodes]
    set dname [dict get $ymlDict sslOptions dname]
    set ext "SAN="
    #SAN=DNS:localhost,DNS:che.intranet.fh.gov.cn,IP:10.74.111.70,IP:127.0.0.1
    foreach n $solrNodes {
      set p [split $n ,]
      if {[llength $p] == 2} {
        set ext "${ext}DNS:[lindex $p 0],IP:[lindex $p 1],"
      } else {
        set ext "${ext}IP:${p},"
      }
    }

    set ext "${ext}DNS:localhost,IP:127.0.0.1"

    #set ext [string range $ext 0 end-1]
    # keytool -genkeypair -alias solr-ssl -keyalg RSA -keysize 2048 -keypass secret -storepass secret -validity 9999 -keystore solr-ssl.keystore.jks -ext SAN=DNS:localhost,DNS:che.intranet.fh.gov.cn,IP:10.74.111.70,IP:127.0.0.1 -dname "CN=solrcloud, OU=fhgov, O=xxzx, L=fenghua, ST=zj, C=cn"
    if {[file exists $keyStore]} {
      exec rm -f $keyStore
    }
    set kcmd "$keytool -genkeypair -alias solr-ssl -keyalg RSA -keysize 2048 -keypass $password -storepass $password -validity 9999 -keystore $keyStore -ext $ext -dname \"$dname\""
    puts $kcmd
    exec {*}$kcmd
    if {[string length $oneZkHost] > 0} {
      exec bash $zkcli -zkhost $oneZkHost -cmd clusterprop -name urlScheme -val https
      puts !!!you must copy /etc/solr-ssl.keystore.jks to every solr node, all must same.!!!
    }
  }
}
