package provide ParamsValidator 1.0
package require CcommonUtil

namespace eval ::ParamsValidator {

}

proc ::ParamsValidator::validate {rawParamDict nameActions} {
  upvar $rawParamDict rpd

  if {! [dict exists $rpd host]} {
    ::CcommonUtil::printHelp
    exit 0
  }

  if {[llength $nameActions] < 2} {
    ::CcommonUtil::printHelp
    exit 0
  }

  set appname [lindex $nameActions 0]

  if {! [::CcommonUtil::isAppName $appname]} {
    puts "'$appname' is not supported yet."
    exit 0
  }
  dict set rpd appname $appname

  if {! [dict exists $rpd mocklist]} {
    dict set rpd mocklist {}
  }

  switch -exact -- $appname {
    boot {
      validateBoot rpd
    }
    mysql {
      validateMysql rpd
    }
    default {}
  }

}

proc ::ParamsValidator::validateBoot {rawParamDict} {
  upvar $rawParamDict rpd
  if {! [dict exists $rpd bootjar]} {
    puts "parameter 'bootjar' is mandatory, which point to a boot application jar."
    exit 0
  }

  if {! [dict exists $rpd springprofile]} {
    puts "parameter 'springprofile' is mandatory, which point to a boot application jar."
    exit 0
  }
}

proc ::ParamsValidator::validateMysql {rawParamDict} {
  upvar $rawParamDict rpd
  if {! [dict exists $rpd profile]} {
    puts "parameter 'profile' is mandatory, which point to a xxx.secret.yml file."
    exit 0
  }
}
