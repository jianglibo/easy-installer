# easy-installer for common server side applications.

Please follow steps below exactly, all installer should work on you desktop.
Look into scripts folder, it organized by applicaion per folder. As an example, we will install a mysql cluster on your desktop.

## Step 1, Install Vagrant and VirtualBox
* Vagrant, from [https://www.vagrantup.com/downloads.html](https://www.vagrantup.com/downloads.html)
* VirtualBox, from [https://www.virtualbox.org/](https://www.virtualbox.org/)
* make a directory on your computer, download or copy content of the "Vagrantfile" in the project root.
* cd into directory just created, run "vagrant up", please be patient, it take times if your network speed is slow.

## Step 2
Now there are 5 virtualBox running, 192.168.33.49,50,51,52,53. We use 49 as a controller, you login to 49, you can install softerware to 50,51,52,53 or every where ssh reachable.

* run "vagrant ssh desktop", then "su root", enter "vagrant" as password for root. "#" prompt should display.
* ***command below are invoked from 49 machine.***
* run "ssh-keygen" hit return return.
* run "ssh-copy-id root@192.168.33.50", when prompt password, enter "vagrant", repeat for 51,52,53
* git clone https://github.com/jianglibo/easy-installer.git; cd easy-installer
* chmod a+x easy-installer.tcl

## Step 3
Let's install java to 50.

./easy-installer.tcl --host=192.168.33.50 java install

or

./easy-installer.tcl --host=192.168.33.50 --DownFrom=http://www.fh.gov.cn/jdk-8u73-linux-x64.tar.gz java install

please change --DownFrom to a faster place.

If it works, We are begin to install a more complex mysql cluster.

## Install Mysql Cluster.

Look into mysql-cluster in scripts folder, there have many tcl files, let's look at local-profile.yml.

local-profile.yml
```
NDB_MGMD_DEFAULT:
  DataDir: /opt/mysql-cluster-mgm
  PortNumber: 41500
  config-dir: /opt/mysql-cluster-mgm
  config-file: /opt/mysql-cluster-mgm/config.ini
NDB_MGMD:
  DataDir: /opt/mysql-cluster-mgm
  nodes:
    - HostName: 192.168.33.50
      NodeId: 50
      PortNumber: 41500
    - HostName: 192.168.33.51
      NodeId: 51
      PortNumber: 41500
NDBD_DEFAULT:
  DataDir: /opt/mysql-cluster-ndbd
NDBD:
  DataDir: /opt/mysql-cluster-ndbd
  nodes:
    - HostName: 192.168.33.52
      NodeId: 1
    - HostName: 192.168.33.53
      NodeId: 2
MYSQLD_DEFAULT:
  Port: 41500
  Socket: /opt/mysql-cluster-mysqld
MYSQLD:
  DataDir: /opt/mysql-cluster-mysqld
  nodes:
    - HostName: 192.168.33.50
      instances:
        - NodeId: 100
          Port: 41510
        - NodeId: 101
          Port: 41511
    - HostName: 192.168.33.51
      instances:
        - NodeId: 102
          Port: 41510
        - NodeId: 103
          Port: 41511

```
We run:
* 2 cluster manager on 50,51.
* 2 data node on 52,53
* 4 sql node on 50,51. 2 instances each.

Invoke this command to complete Mysql Cluster install:

* ./easy-installer.tcl --host=192.168.33.50,51,52,53 --profile=local-profile.yml mysql-cluster install config mgmstart ndbdstart mysqldstart

*** the pattern is: parameters appFolderName action...actions ***

It take long time to install, If account any error, you can reinvoke command again, It will continue from where broken.

After install complete, ssh into 50, invoke "ndb_mgm -e show", you should see:

```
[root@localhost ~]# ndb_mgm -e show
Connected to Management Server at: 192.168.33.50:41500
Cluster Configuration
---------------------
[ndbd(NDB)]     2 node(s)
id=1    @192.168.33.52  (mysql-5.6.28 ndb-7.4.10, Nodegroup: 0, *)
id=2    @192.168.33.53  (mysql-5.6.28 ndb-7.4.10, Nodegroup: 0)

[ndb_mgmd(MGM)] 2 node(s)
id=50   @192.168.33.50  (mysql-5.6.28 ndb-7.4.10)
id=51   @192.168.33.51  (mysql-5.6.28 ndb-7.4.10)

[mysqld(API)]   4 node(s)
id=100  @192.168.33.50  (mysql-5.6.28 ndb-7.4.10)
id=101  @192.168.33.50  (mysql-5.6.28 ndb-7.4.10)
id=102  @192.168.33.51  (mysql-5.6.28 ndb-7.4.10)
id=103  @192.168.33.51  (mysql-5.6.28 ndb-7.4.10)
```
It's running!

## Limitation

Current support Centos only. But for other os, the difference is the package installer. apt-get or yum or something like.
