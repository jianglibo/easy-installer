package provide XmlWriter 1.0
package require CommonUtil
package require PropertyUtil
package require OsUtil

namespace eval XmlWriter {
  variable dfsNamenodeNameDir dfs.namenode.name.dir
  variable dfsDatanodeDataDir dfs.datanode.data.dir
}

proc ::XmlWriter::prepareDic {ymlDict dic} {
  set DataDirBase [dict get $ymlDict DataDirBase]
  set dnnd dfs.namenode.name.dir
  set dddd dfs.datanode.data.dir

  if {[dict exists $dic $dnnd]} {
    dict set dic $dnnd [file join $DataDirBase [dict get $dic $dnnd]]
  }

  if {[dict exists $dic $dddd]} {
    dict set dic $dddd [file join $DataDirBase [dict get $dic $dddd]]
  }
  return $dic
}

proc ::XmlWriter::addOneProperty {lines k v} {
  upvar $lines ln
  lappend ln "<property>"
  lappend ln "<name>$k</name>"
  lappend ln "<value>$v</value>"
  lappend ln "</property>"
}

proc ::XmlWriter::write {fn lines} {
  if {[catch {open $fn w} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    foreach line $lines {
      puts $fid $line
    }
    close $fid
  }
}

proc ::XmlWriter::copyOrigin {fn} {
  if {[file exists "${fn}.origin"]} {
    exec cp "${fn}.origin" $fn
  } else {
    exec cp $fn "${fn}.origin"
  }
}
proc ::XmlWriter::createDir {hadoopHome cfdir} {
  if {[regexp {^\.\W*(\w+)$} $cfdir mh m1]} {
    set cfdir [file join $hadoopHome $m1]
  }

  if {! [file exists $cfdir]} {
    exec mkdir -p $cfdir
  }
  return [file normalize $cfdir]
}

proc ::XmlWriter::yarnSite {hadoopHome nodeYml ymlDict} {
  set yarnSiteFile [file join $hadoopHome etc hadoop yarn-site.xml]
  set siteDic [prepareDic $ymlDict [dict get $nodeYml YarnSiteCfg]]
  copyOrigin $yarnSiteFile
  set lines [list]
  lappend lines {<?xml version="1.0"?>}
  lappend lines {<configuration>}

  dict for {k v} $siteDic {
    addOneProperty lines $k $v
  }
  lappend lines {</configuration>}
  write $yarnSiteFile $lines
}

proc ::XmlWriter::coreSite {hadoopHome nodeYml ymlDict} {
  set coreSiteFile [file join $hadoopHome etc hadoop core-site.xml]
  set siteDic [prepareDic $ymlDict [dict get $nodeYml CoreSiteCfg]]
  copyOrigin $coreSiteFile
  set lines [list]
  lappend lines {<?xml version="1.0" encoding="UTF-8"?>}
  lappend lines {<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>}
  lappend lines {<configuration>}

  dict for {k v} $siteDic {
    addOneProperty lines $k $v
  }
  lappend lines {</configuration>}
  write $coreSiteFile $lines
}


proc ::XmlWriter::hdfsSite {hadoopHome nodeYml ymlDict} {
  variable dfsDatanodeDataDir
  variable dfsNamenodeNameDir

  set hdfsSiteFile [file join $hadoopHome etc hadoop hdfs-site.xml]
  set siteDic [prepareDic $ymlDict [dict get $nodeYml HdfsSiteCfg]]
  copyOrigin $hdfsSiteFile
  set lines [list]
  lappend lines {<?xml version="1.0" encoding="UTF-8"?>}
  lappend lines {<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>}
  lappend lines {<configuration>}

  switch -exact -- [dict get $nodeYml role] {
    NameNode {
      set normalizedDir [createDir $hadoopHome [dict get $siteDic $dfsNamenodeNameDir]]
      dict set siteDic $dfsNamenodeNameDir $normalizedDir
    }
    DataNode {
      set normalizedDir [createDir $hadoopHome [dict get $siteDic $dfsDatanodeDataDir]]
      dict set siteDic $dfsDatanodeDataDir $normalizedDir
    }
    default {}
  }

  dict for {k v} $siteDic {
    addOneProperty lines $k $v
  }

  lappend lines {</configuration>}
  write $hdfsSiteFile $lines
}
