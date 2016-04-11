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

## Limitation

Current support Centos only. But for other os, the difference is the package installer. apt-get or yum or something like.
