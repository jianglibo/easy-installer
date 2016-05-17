## Usage

tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --mocklist=hadoop-home --profile=home hbase install

## Example cluster

* 192.168.33.50 roles: Zookper Master
* 192.168.33.51 roles: Zookper RegionServer
* 192.168.33.52 roles: Zookper RegionServer
* 192.168.33.54 roles: backup

## Example cluster install
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --mocklist=hadoop-home --profile=home hbase install
* tclsh easy-installer.tcl --host=192.168.33.50 --mocklist=hadoop-home --profile=home hbase start
* tclsh easy-installer.tcl --host=192.168.33.50 --mocklist=hadoop-home --profile=home hbase stop

## web
http://192.168.33.50:16010

## Office

tclsh easy-installer.tcl --host=10.74.111.62,63,64,65,66 --mocklist=hadoop-office --profile=office hbase install

## Example cluster

* 10.74.111.62 roles: Zookper Master
* 10.74.111.63 roles: Zookper RegionServer
* 10.74.111.64 roles: Zookper RegionServer
* 10.74.111.65 roles: Zookper RegionServer
* 10.74.111.66 roles: backup

## Example cluster install
* tclsh easy-installer.tcl --host=10.74.111.62,63,64,65,66 --mocklist=hadoop-office --profile=office hbase install
* tclsh easy-installer.tcl --host=10.74.111.62 --mocklist=hadoop-office --profile=office hbase start
* tclsh easy-installer.tcl --host=10.74.111.62 --mocklist=hadoop-office --profile=office hbase stop

## web
http://10.74.111.62:16010
