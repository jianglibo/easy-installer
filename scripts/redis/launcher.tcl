catch {[exec systemctl list-unit-files | grep redis]} units

if {[lsearch units redis.service] != -1} {
	puts stdout "redis already installed.!"
	exit 0
}

set redisFolder /opt/redis
set redisFile redis-3.0.7.tar.gz
set fileUrl http://www.fh.gov.cn/$redisFile

set unitFile /etc/systemd/system/redis.service

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
}

if {[file exists $unitFile]} {
	puts stdout "redis unit file already exists. skip creating..."
} else {
	# create unit file
	set unitFd [open $unitFile w]
	set content {
		[Unit]
		Description= Redis server
		After=network.target

		[Service]
		ExecStart=%s/src/redis-server %s/redis.conf
		Type=simple
		PIDFile=/var/run/redis.pid

		[Install]
		WantedBy=multi-user.target
	}
	foreach line [split [format $content $redisFolder/$extractFolder $redisFolder/$extractFolder] \n] {
		puts $line........
		puts $unitFd [string trim $line]
	}
	close $unitFd
	#code line in catch may output content to stderr, that make tcl script looks like wrong, but actually not.
	catch {
		exec systemctl daemon-reload
		exec systemctl enable redis.service
	} msg

	puts stdout $msg

}

puts stdout "redis installed successly. starting reids..."
exec systemctl start redis.service
