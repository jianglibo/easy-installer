#!/bin/sh
# boot-run-systemd.tcl \
exec tclsh "$0" ${1+"$@"}

set runUser @runUser@
set bootRunFolder @bootRunFolder@
set jarFile @jarFile@
set profile @profile@
set pidFile @pidFile@

cd $bootRunFolder

#su -c "java -jar -Dspring.profiles.active=prod web-proxy-0.0.1.jar" -s /bin/sh webproxy

#set exeCmd "su -c \"java -jar -Dspring.profiles.active=$profile [file tail $jarFile] -s /bin/sh $runUser >> nohup.log 2>&1\""
#set pidf [exec {*}$exeCmd &]


#set fid [open "| su -c  \"java -jar -Dspring.profiles.active=$profile $jarFile\" -s /bin/bash $runUser"]
set fid [exec sudo -u $runUser java -jar -Dspring.profiles.active=$profile $jarFile >>& nohup.log &]
puts $fid
#exec echo [pid $fid] > $pidFile
exec echo $fid > $pidFile
#puts [pid]
#set nohup [open nohup.log a+]
#while {[gets $fid line] >= 0} {
#    puts $nohup $line
#}
