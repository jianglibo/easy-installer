package provide SolrCreator 1.0
package require CommonUtil
package require OsUtil
package require SslSetup
package require IniWriter

if {0} {
  Usage: solr create_core [-c core] [-d confdir] [-p port]

    -c <core>     Name of core to create

    -d <confdir>  Configuration directory to copy when creating the new core, built-in options are:

        basic_configs: Minimal Solr configuration
        data_driven_schema_configs: Managed schema with field-guessing support enabled
        sample_techproducts_configs: Example configuration with many optional features enabled to
           demonstrate the full power of Solr

        If not specified, default is: data_driven_schema_configs

        Alternatively, you can pass the path to your own configuration directory instead of using
        one of the built-in configurations, such as: bin/solr create_core -c mycore -d /tmp/myconfig

    -p <port>     Port of a local Solr instance where you want to create the new core
                    If not specified, the script will search the local system for a running
                    Solr instance and will use the port of the first server it finds.
}

namespace eval SolrCreator {
}

proc ::SolrInstaller::create {ymlDict rawParamDict} {
  set include [dict get $ymlDict SolrInclude]
  set solrBin [file normalize [file join [dict get $ymlDict SolrInstallFolder] $include]]

  if {! [file exists $installFolder]} {
    exec mkdir -p $installFolder
  }
  set user [dict get $ymlDict SolrUser]
  set port [dict get $ymlDict SolrPort]

  set iniFile "/etc/default/${include}.in.sh"
  # /etc/default/solr.in.sh
  # puts [pwd]
  set cmd "bash $installExec [file join $tmpFolder $tzName] -i $installFolder -d $dataFolder -u $user -s $include -p $port"
  if {[dict exists $rawParamDict force]} {
    puts "force installing............."
    set cmd "$cmd -f"
  }

  if {[catch {exec {*}$cmd} msg o]} {
    puts "catched exception."
    puts $msg
  }

  ::OsUtil::openFirewall tcp $port

  if {[catch {exec service solr stop} msg o]} {
    puts "catched exception."
    puts $msg
  }

  set zkcli [file join $installFolder solr server scripts cloud-scripts zkcli.sh]
  set oneZkHost {}


  if {[dict exists $ymlDict Ini] && [dict exists $ymlDict Ini ZK_HOST]} {
    set oneZkHost [lindex [split [dict get $ymlDict Ini ZK_HOST] /] 0]

    if {[catch {exec bash $zkcli -zkhost $oneZkHost  -cmd makepath /solr} msg o]} {
      puts "catched exception."
      puts $msg
    }
  }

  catch {exec service solr stop} msg o

  ::IniWriter::changeIni $iniFile $ymlDict
  ::SslSetup::setup $ymlDict $zkcli $oneZkHost
  exec service solr start
}
