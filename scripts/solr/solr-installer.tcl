package provide SolrInstaller 1.0
package require CommonUtil
package require OsUtil
package require SslSetup
package require IniWriter

namespace eval SolrInstaller {
}

proc ::SolrInstaller::install {ymlDict rawParamDict} {
  set tmpFolder /opt/solr-tmp-install
  if {! [file exists $tmpFolder]} {
    exec mkdir -p $tmpFolder
  }

  set pwd [pwd]
  set from [dict get $ymlDict DownFrom]
  set tzName [lindex [split $from /] end]

  cd $tmpFolder

  if {! [file exists $tzName]} {
    ::CommonUtil::spawnCommand curl -OL $from
  }

  set extractedFolder [glob -nocomplain -directory $tmpFolder -type d *]

  if {[llength $extractedFolder] == 0} {
    if {[catch {exec tar -zxf $tzName} msg o]} {
      puts "$tzName is damaged. please try again."
      exec rm -f $tzName
      exec rm -rf $extractedFolder
      ::CommonUtil::endEasyInstall
    }
  }
  set extractedFolder [glob -nocomplain -directory $tmpFolder -type d *]
  set extractedFolder [file normalize [lindex $extractedFolder 0]]
  set installExec [file join $extractedFolder bin install_solr_service.sh]
  # sudo bash ./install_solr_service.sh solr-X.Y.Z.tgz -i /opt -d /var/solr -u solr -s solr -p 8983
  set dataFolder [dict get $ymlDict SolrDataFolder]
  set installFolder [dict get $ymlDict SolrInstallFolder]
  
  if {! [file exists $installFolder]} {
    exec mkdir -p $installFolder
  }
  set user [dict get $ymlDict SolrUser]
  set port [dict get $ymlDict SolrPort]
  set include [dict get $ymlDict SolrInclude]
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


  # bash /opt/solrapp/solr/server/scripts/cloud-scripts/zkcli.sh -zkhost nn.intranet.fh.gov.cn:2181/solr -cmd list
  # First, if you don't provide the -d or -n options, then the default configuration ($SOLR_HOME/server/solr/configsets/data_driven_schema_configs/conf) is uploaded to ZooKeeper using the same name as the collection
  # bin/solr create -c testlogs === http://localhost:8983/solr/admin/collections?action=CREATE&name=testlogs&numShards=1&replicationFactor=1&maxShardsPerNode=1&collection.configName=testlogs
  # bin/solr create -c logs -d solrapp/solr/server/solr/configsets/basic_configs/conf/basic_configs -n basic
  catch {exec service solr stop} msg o

  ::IniWriter::changeIni $iniFile $ymlDict
  ::SslSetup::setup $ymlDict $zkcli $oneZkHost
  exec service solr start


  # /solrapp/solr-6.1.0/server/solr/configsets/data_driven_schema_configs/conf/solrconfig.xml
  # <directoryFactory name="DirectoryFactory" class="solr.HdfsDirectoryFactory">
  # <str name="solr.hdfs.home">hdfs://host:port/solr</str>
  #<bool name="solr.hdfs.blockcache.enabled">true</bool>
  #<int name="solr.hdfs.blockcache.slab.count">1</int>
  #<bool name="solr.hdfs.blockcache.direct.memory.allocation">true</bool>
  #<int name="solr.hdfs.blockcache.blocksperbank">16384</int>
  #<bool name="solr.hdfs.blockcache.read.enabled">true</bool>
  #<bool name="solr.hdfs.nrtcachingdirectory.enable">true</bool>
  #<int name="solr.hdfs.nrtcachingdirectory.maxmergesizemb">16</int>
  #<int name="solr.hdfs.nrtcachingdirectory.maxcachedmb">192</int>
  #</directoryFactory>

  #<lib dir="${solr.install.dir:../../../..}/contrib/map-reduce/lib" regex=".*\.jar" />
  #<lib dir="${solr.install.dir:../../../..}/dist/" regex="solr-map-reduce-\d.*\.jar" />

}
