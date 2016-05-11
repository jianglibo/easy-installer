sed -i 's!https://!http://!' a.txt

sed -i 's!^#baseurl=.*!baseurl=http://mirrors.aliyun.com/epel/7/x86_64!' epel.repo
sed -i 's!^mirrorlist=\(.*\)$!#mirrorlist=\1!' epel.repo
