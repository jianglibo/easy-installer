package provide XmlWriter 1.0
package require CommonUtil
package require PropertyUtil
package require OsUtil

namespace eval XmlWriter {
}

proc ::XmlWriter::addOneProperty {lines k v} {
  upvar $lines ln
  lappend ln "<property>}"
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

proc ::XmlWriter::coreSite {hadoopHome confYml} {
  set coreSiteFile [file join $hadoopHome etc hadoop core-site.xml]
  copyOrigin $coreSiteFile
  set lines [list]
  lappend lines {<?xml version="1.0" encoding="UTF-8"?>}
  lappend lines {<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>}
  lappend lines {<configuration>}

  dict for {k v} $confYml {
    addOneProperty lines k v
  }
  lappend lines {</configuration>}
  write $coreSiteFile $lines
}

proc ::XmlWriter::hdfsSite {hadoopHome confYml} {
  set coreSiteFile [file join $hadoopHome etc hadoop hdfs-site.xml]
  copyOrigin $coreSiteFile
  set lines [list]
  lappend lines {<?xml version="1.0" encoding="UTF-8"?>}
  lappend lines {<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>}
  lappend lines {<configuration>}

  dict for {k v} $confYml {
    addOneProperty lines k v
  }
  lappend lines {</configuration>}
  write $coreSiteFile $lines
}
