#!/bin/sh
# install-redis.tcl \
exec tclsh "$0" ${1+"$@"}

if {[file exists /var/run/redis.pid]} {
	puts stdout "redis already running!"
	exit 0
}

set redisFolder /opt/redis
set redisFile redis-3.0.7.tar.gz
set fileUrl http://www.fh.gov.cn/$redisFile

catch {[exec cc --version]} msg

puts stdout $msg

if {[string match "*command not found*" $msg] || [string match "*no such file or directory*" $msg]} {
	puts stdout "gcc not installed, start to install."
	exec yum install -y gcc
	puts stdout "gcc install successly."
}

if {! [file exists $redisFolder]} {
	exec mkdir -p $redisFolder
}

cd $redisFolder

if {! [file exists $redisFolder/$redisFile]} {
  puts stdout "start downloading $fileUrl ....\n"
	exec curl -O $fileUrl >&  curloutput.log
	puts stdout "download finished.\n"
}

if {! [file exists $redisFolder/$redisFile]} {
	puts stdout "download $fileUrl failed."
	exit 2
}

if {[file size $redisFolder/$redisFile] < 10000} {
	puts stdout "download $fileUrl failed.deleting partial file..."
	file delete $redisFolder/$redisFile
	exit 2
}

set extractFolder [join [lrange [split $redisFile .] 0 end-2] .]

# not installed yet.
if {[file exists $extractFolder/src/redis-server]} {
	cd $extractFolder
} else {
	cd $redisFolder

	exec tar -zxf $redisFile

	cd $extractFolder
	set code [catch {[exec make]} msg]

	if {! [string match "*It's a good idea to run 'make test'*" $msg]} {
		exec make distclean
		set code [catch {[exec make]} msg]
	}

	if {! [string match "*It's a good idea to run 'make test'*" $msg]} {
		puts stdout "make failed!"
		exit 1
	}

	file copy redis.conf [clock format [clock seconds] -format redis.conf-%Y-%m-%d:%H:%M:%S]

	set confFd [open redis.conf]
	set cont [read $confFd]
	close $confFd

	set lines [split $cont \n]

	set lnum [lsearch $lines "daemonize*"]
	set daeline [lindex $lines $lnum]
	set replacedLines [lreplace $lines $lnum $lnum "daemonize yes"]

	set confFd [open redis.conf w]
	foreach line $replacedLines {
		puts $confFd $line
	}
	close $confFd
}

puts stdout "redis installed successly. starting reids..."
exec src/redis-server redis.conf
puts stdout "start successly"
