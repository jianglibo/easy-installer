package provide RabbitmqInstaller 1.0
package require CommonUtil

namespace eval RabbitmqInstaller {
}

proc ::RabbitmqInstaller::install {ymlDict rawParamDict} {
  catch {exec chkconfig --list | grep rabbitmq} sl
  if {[string match *rabbitmq-server* $sl]} {
  	puts stdout "rabbitmq already installed!"
  	::CommonUtil::endEasyInstall
  }

  set tmpDir /opt/install-tmp
  set rpmName rabbitmq-server-3.6.1-1.noarch.rpm

  if {! [file exists $tmpDir]} {
    exec mkdir -p $tmpDir
  }

  cd $tmpDir

  ::CommonUtil::spawnCommand curl -OL http://www.rabbitmq.com/releases/rabbitmq-server/v3.6.1/$rpmName

  ::CommonUtil::spawnCommand yum -y install erlang
  set asc %s://www.rabbitmq.com/rabbitmq-signing-key-public.asc

  if {[dict exists $rawParamDict mocklist]} {
    ::CommonUtil::spawnCommand rpm --import [format $asc http]
  } else {
    ::CommonUtil::spawnCommand rpm --import [format $asc https]
  }
  ::CommonUtil::spawnCommand yum -y install $rpmName
  if {[dict get $ymlDict webPlugin]} {
    exec rabbitmq-plugins enable rabbitmq_management
  }

  set firstUser [dict get $ymlDict firstUser]
  exec chkconfig rabbitmq-server on
  exec systemctl start rabbitmq-server
  exec rabbitmqctl add_user $firstUser [dict get $ymlDict password]
  exec rabbitmqctl delete_user guest
  exec rabbitmqctl set_user_tags $firstUser administrator
  exec rabbitmqctl set_permissions -p / firstUser ".*" ".*" ".*"
  exec rm $tmpDir/$rpmName
}
