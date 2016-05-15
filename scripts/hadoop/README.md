## Usage

tclsh easy-installer.tcl --host=192.168.33.50 --mocklist=hadoop-home --profile=home hadoop install

## Example cluster

* 192.168.33.50 roles: NameNode ResourceManager
* 192.168.33.51 roles: DataNode NodeManager
* 192.168.33.52 roles: DataNode NodeManager
* 192.168.33.53 roles: webproxy dnsserver
* 192.168.33.54 roles: NameNode

## Example cluster install
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --mocklist=hadoop-home --profile=home hadoop install
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --notRunBash=true --mocklist=hadoop-home --profile=home hadoop formatCluster
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54  --notRunBash=true --mocklist=hadoop-home --profile=home hadoop start
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54  --notRunBash=true --mocklist=hadoop-home --profile=home hadoop stop

## web
http://192.168.33.50:50070/
