
echo "start running very-early.bash"
epelHost="mirrors.fedoraproject.org"
epelRepo="/etc/yum.repos.d/epel.repo"

centosBaseRepo="/etc/yum.repos.d/CentOS-Base.repo"

origin="/etc/hosts.origin"
yumPid="/var/run/yum.pid"

mocklist=$1
if [ -f "$origin" ]
then
	cp "$origin" /etc/hosts
else
	cp /etc/hosts "$origin"
fi

if [ $mocklist ]
then
  sed -i 's/\r//' $mocklist
  cat $mocklist >> /etc/hosts
	if [ ! -f $epelRepo ]
	then
		yum install -y epel-release
	fi

	if [ -f "${epelRepo}.origin" ]
	then
		cp "${epelRepo}.origin" $epelRepo
	else
		cp $epelRepo "${epelRepo}.origin"
	fi

	if [ -f "${centosBaseRepo}.origin" ]
	then
		cp "${centosBaseRepo}.origin" $centosBaseRepo
	else
		cp $centosBaseRepo "${centosBaseRepo}.origin"
	fi


	sed -i 's!^#baseurl=http://download.fedoraproject.org/pub\(.*\)$!baseurl=http://mirrors.aliyun.com\1!' $epelRepo
	sed -i 's!^mirrorlist=\(.*\)$!#mirrorlist=\1!' $epelRepo

	sed -i 's!^#baseurl=http://mirror.centos.org\(.*\)$!baseurl=http://mirrors.aliyun.com\1!' $centosBaseRepo
	sed -i 's!^mirrorlist=\(.*\)$!#mirrorlist=\1!' $centosBaseRepo

fi

if [ -f "$yumPid" ]
then
	echo "killing running yum."
	cat $yumPid |xargs kill -s 9
fi

yum install -y tcl tcllib expect dos2unix epel-release
