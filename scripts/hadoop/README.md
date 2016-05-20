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
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --mocklist=hadoop-home --profile=home hadoop formatCluster
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54  --mocklist=hadoop-home --profile=home hadoop start
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54  --mocklist=hadoop-home --profile=home hadoop stop

## web
http://192.168.33.50:50070/

## Example cluster Office

* 10.74.111.62 roles: NameNode ResourceManager
* 10.74.111.63 roles: DataNode NodeManager
* 10.74.111.64 roles: DataNode NodeManager
* 10.74.111.65 roles: DataNode NodeManager
* 10.74.111.66 roles: NameNode

## Example cluster install Office
* tclsh easy-installer.tcl --host=10.74.111.62,63,64,65,66 --mocklist=hadoop-office --profile=office-2.5.2 hadoop install
* tclsh easy-installer.tcl --host=10.74.111.62,63,64,65,66 --mocklist=hadoop-office --profile=office-2.5.2 hadoop formatCluster
* tclsh easy-installer.tcl --host=10.74.111.62,63,64,65,66 --profile=office-2.5.2 hadoop start
* tclsh easy-installer.tcl --host=10.74.111.62,63,64,65,66 --profile=office-2.5.2 hadoop stop

## web Office
http://10.74.111.62:50070/
http://10.74.111.62:8088/ resourcemanager.
