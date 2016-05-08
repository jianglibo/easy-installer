package provide BootSetup 1.0
package require CommonUtil

namespace eval BootSetup {
}

proc ::BootSetup::init {ymlDict rawParamDict} {
  puts $::baseDir
  set bootjar [dict get $rawParamDict bootjar]
  regexp {(.*)-\d+\.} $bootjar m serviceName
  set runUser [string map {- {}} $serviceName]
  set runGroup $runUser
  set bootRunFolder /opt/$serviceName

  set unitFile /etc/systemd/system/${serviceName}.service

  if {[catch {exec which java} msg o]} {
    puts "please install java first."
    ::CommonUtil::endEasyInstall
  }
  set javaExec [exec which java]
  set systemdExec [file join $bootRunFolder boot-run-systemd.tcl]
  set pidFile "${bootRunFolder}/${serviceName}.pid"

  if {! [file exists $bootRunFolder]} {
    exec mkdir -p $bootRunFolder
  }

  foreach jar [glob -directory [file join $::baseDir] -types f -- *.jar] {
    set tname [file join $bootRunFolder [file tail $jar]]
    set oname "${tname}.origin"
    if {[file exists $tname]} {
      if {[file exists $oname]} {
        exec rm -f $oname
      }
      exec mv $tname $oname
    }
    puts $jar
    exec cp $jar $tname
  }

  if {[catch {exec grep -Ei "^${runUser}:" /etc/passwd} msg o]} {
    exec groupadd $runGroup
    exec useradd -r -g $runGroup -s /bin/false $runUser
  }

  exec chown -R "${runUser}:${runGroup}" $bootRunFolder

  set strMap "@bootRunFolder@ $bootRunFolder @jarFile@ $tname @profile@ [dict get $rawParamDict springprofile ] @runUser@ $runUser @pidFile@ $pidFile"

  if {[catch {open [file join $::baseDir [dict get $rawParamDict runFolder] boot-run-systemd.tcl]} fid o]} {
    puts stdout $fid
    exit 1
  } else {
    set lines [list]
    while {[gets $fid line] >= 0} {
      lappend lines [string map $strMap $line]
    }
    close $fid

    if {[catch {open $systemdExec w} fid o]} {
      puts $fid
      ::CommonUtil::endEasyInstall
    } else {
      foreach line $lines {
        puts $fid $line
      }
      close $fid
    }
  }

  exec chown -R ${runUser}:${runGroup} $bootRunFolder

  exec chmod a+x $systemdExec
  	# create unit file
    # Type=simple
    # Type = forking
  set unitFd [open $unitFile w]
  set content {
  	[Unit]
  	Description= %s server
  	After=network.target
  	[Service]
  	ExecStart=%s
  	Type=forking
  	PIDFile=%s
  	[Install]
  	WantedBy=multi-user.target
  }
  foreach line [split [format $content $serviceName $systemdExec $pidFile] \n] {
    puts $unitFd [string trim $line]
  }
  close $unitFd
  	#code line in catch may output content to stderr, that make tcl script looks like wrong, but actually not.

  if {[::CommonUtil::sysRunning $serviceName]} {
    puts "$serviceName is running. stoping..."
    ::CommonUtil::spawnCommand systemctl stop $serviceName
  }
  ::CommonUtil::spawnCommand systemctl daemon-reload
	::CommonUtil::spawnCommand systemctl enable ${serviceName}.service
  ::CommonUtil::spawnCommand systemctl start $serviceName
}
