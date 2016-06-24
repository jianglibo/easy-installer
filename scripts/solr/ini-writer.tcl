package provide IniWriter 1.0
package require OsUtil

namespace eval IniWriter {
  variable lines [list]
}
# return processed
proc ::IniWriter::processZkHost {ymlDict line} {
  variable lines
  if {[dict exists $ymlDict Ini ZK_HOST]} {
    lappend lines "ZK_HOST=\"[dict get $ymlDict Ini ZK_HOST]\""
    return 1
  }
  return 0
}

proc ::IniWriter::getSolrOptNames {ymlDict} {
  set opts [list]
  foreach optline [dict get $ymlDict solrOptions] {
    lappend opts [lindex [split $optline =] 0]
  }
  return $opts
}

proc ::IniWriter::isOptLine {optNames line} {
  foreach opt $optNames {
    if {[string first # $line] == 0} {
      return 0
    }
    if {[string match "*$opt*" $line]} {
      return 1
    }
  }
  return 0
}

proc ::IniWriter::changeIni {iniFile ymlDict} {
  variable lines
  set optNames [getSolrOptNames $ymlDict]
  if {[catch {open $iniFile} fid o]} {
    puts $fid
    ::CommonUtil::endEasyInstall
  } else {
    while {[gets $fid line] >= 0} {
      set processed 0
      if {[string match *ZK_HOST=* $line]} {
        set processed [processZkHost $ymlDict $line]
      } elseif {[isOptLine $optNames $line]} {
        set processed 1
      } elseif {[isOptLine [dict keys [dict get $ymlDict sslOptions ini]] $line]} {
        set processed 1
      }
      if {! $processed} {
        lappend lines $line
      }
    }
    close $fid
  }
    #SOLR_OPTS="$SOLR_OPTS -Dsolr.autoSoftCommit.maxTime=3000"
    foreach optline [dict get $ymlDict solrOptions] {
      lappend lines "SOLR_OPTS=\"\$SOLR_OPTS $optline\""
    }

    dict for {k v} [dict get $ymlDict sslOptions ini] {
      lappend lines ${k}=$v
    }

    if {[catch {open $iniFile w} fid o]} {
      puts $fid
      ::CommonUtil::endEasyInstall
    } else {
      foreach line $lines {
        puts $fid $line
      }
      close $fid
    }
}
