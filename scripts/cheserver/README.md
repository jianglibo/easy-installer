## Usage

tclsh easy-installer.tcl --host=10.74.111.70 cheserver install

tclsh easy-installer.tcl --host=10.74.111.70 cheserver start
tclsh easy-installer.tcl --host=10.74.111.70 cheserver stop


cd /opt/che/eclixx
nohup runuser -u che ./bin/che.sh run &

che.properties
machine.docker.local_node_host=che.intranet.fh.gov.cn
