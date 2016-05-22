## Usage

tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --mocklist=hadoop-home --profile=home hbase install

## Example cluster

* 192.168.33.50 roles: Zookper Master
* 192.168.33.51 roles: Zookper RegionServer
* 192.168.33.52 roles: Zookper RegionServer
* 192.168.33.54 roles: backup

## Example cluster install
* tclsh easy-installer.tcl --host=192.168.33.50,51,52,54 --mocklist=hadoop-home --profile=home hbase install
* tclsh easy-installer.tcl --host=192.168.33.50 --notRunBash=true --mocklist=hadoop-home --profile=home hbase start
* tclsh easy-installer.tcl --host=192.168.33.50 --notRunBash=true --mocklist=hadoop-home --profile=home hbase stop

## web
http://192.168.33.50:16010
