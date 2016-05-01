package provide Mycnf 1.0

package require CommonUtil

namespace eval ::Mycnf {
}

proc ::Mycnf::substituteAndWrite {tpl nodeYml dst} {
  ::CommonUtil::backupOrigin $dst

  if {[catch {open $dst w} fid o]} {
    puts stdout $fid
    ::CommonUtil::endEasyInstall
  } else {
    foreach line [::CommonUtil::replaceFileContent $tpl $nodeYml] {
      puts $fid $line
    }
    puts $fid \n
    close $fid
  }
}
