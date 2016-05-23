package require JavaInstaller

if {[dict exists $::rawParamDict force]} {
  ::JavaInstaller::install 1
} else {
  ::JavaInstaller::install 0
}
