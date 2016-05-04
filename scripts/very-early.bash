
echo "start running very-early.bash"
epelHost="mirrors.fedoraproject.org"
epelRepo="/etc/yum.repos.d/epel.repo"
epelRepoOrigin="/etc/yum.repos.d/epel.repo.origin"

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
	if [ -f $epelRepoOrigin ]
	then
		cp $epelRepoOrigin $epelRepo
	else
		cp $epelRepo $epelRepoOrigin
	fi
	sed -i 's!^#baseurl=http://download.fedoraproject.org/pub\(.*\)$!baseurl=http://mirrors.aliyun.com\1!' $epelRepo
	sed -i 's!^mirrorlist=\(.*\)$!#mirrorlist=\1!' $epelRepo
fi

if [ -f "$yumPid" ]
then
	echo "killing running yum."
	cat $yumPid |xargs kill -s 9
fi

yum install -y tcl tcllib expect dos2unix epel-release

#if [ $mocklist ]
#then
#  epelInFile=$(grep $epelHost $1)
#  if [ $epelInFile ]
#  then
#    sed -i 's!https://!http://!' $epelRepo
#  fi
#fi
