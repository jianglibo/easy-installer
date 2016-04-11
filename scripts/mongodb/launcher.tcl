
set confFile /etc/mongod.conf

if {[file exists $confFile]} {
	puts stdout "mongodb already installed!"
	set confFd [open $confFile]
	set lines {}
	set replaced false
	while {[gets $confFd line] >= 0} {
		if {[string match *bindIp:* $line] && ([string first # $line] != 0)} {
			lappend lines #$line
			set replaced true
		} else {
			lappend lines $line
		}
	}
	close $confFd

	if $replaced {
		puts stdout "bindIp comment outed."
		set confFd [open $confFile w]
		foreach line $lines {
			puts $confFd $line
		}
		close $confFd
	} else {
		puts stdout "already comment outed.do nothing."
	}
} else {
	exec rpm --import https://www.mongodb.org/static/pgp/server-3.2.asc
	catch {[exec mkdir -p /etc/yum.repos.d]}
	set repofd [open /etc/yum.repos.d/mongodb-org-3.2.repo w]
	puts $repofd {[mongodb-org-3.2]}
	puts $repofd "name=MongoDB Repository"
	puts $repofd "baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/3.2/x86_64/"
	puts $repofd gpgcheck=1
	puts $repofd enabled=1

	close $repofd

	puts stdout [exec yum repolist]
	catch {[exec -- yum --enablerepo=mongodb* install -y mongodb-org]} msg

	if {[string match "*No package * available*" $msg]} {
		puts "install mongodb failed. please try again."
		exit 1
	}
}

puts stdout "starting mongodb...."
exec systemctl restart mongod
