# easy-installer for common server side applications.

## Prepare

* Install Cygwin, include tcl, tclib package.
* In Cygwin, run ssh-keygen, then ssh-copy-id to ```root@target.host```
* Download or clone this project.

## Examples

### Java
```
easy-installer --host=192.168.33.50 java install
easy-installer --host=192.168.33.50 --profile=local-profile.yml java install
easy-installer --host=192.168.33.50 --DstFolder=/opt/myjava --DownFrom=http://somewhere/jdk.tar.gz java install
# --DstFolder override config in local-profile.yml
```

### MySql

content in local-profile.yml
```
MASTER:
  HostName: 192.168.33.53

SLAVES:
  - HostName: 192.168.33.52
    EnableBinLog: 0
  - HostName: 192.168.33.51
    EnableBinLog: 0

ALLOWED_USERS:
  - HostName: 192.168.33.1
    UserName: firstuser
    DbName: firstdb
    Password: ux131415N!
```

```
easy-installer --host=192.168.33.50 -profile=local-profile.yml mysql install
```


### MySql Cluster

```
easy-installer --host=192.168.33.50,51,52,53 -profile=local-profile.yml mysql-cluster install
```

## Limitation

Current support Centos only. But for other os, the difference is the package installer. apt-get or yum or something like.
