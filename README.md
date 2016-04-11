# easy-installer for common server side applications.

## Prepare

* Install Cygwin, include tcl, tclib package.
* In Cygwin, run ssh-keygen, then ssh-copy-id to ```root@target.host```
* Download or clone this project.

## Examples

### Java
```
easy-installer --host=192.168.33.50 java install
```

### MySql

```
easy-installer --host=192.168.33.50 -profile=local-profile.yml mysql install
```

### MySql Cluster

```
easy-installer --host=192.168.33.50,51,52,53 -profile=local-profile.yml mysql-cluster install
```

## TODO

Need to add more config options in profile.yml, For example:

java-install.tcl
```
namespace eval JavaInstaller {
	variable javaFolder /opt/java
	variable jdkFile jdk-8u73-linux-x64.tar.gz
	variable jdkFolder jdk1.8.0_73
	variable fileHost http://www.fh.gov.cn
}
```

Download jdk from china is very slow, So I setup a new webserver to serve it.But this site maybe not fast from your location, So must let it configable.

## Limitation

Current support Centos only. But for other os, the difference is the package installer. apt-get or yum or something like.
