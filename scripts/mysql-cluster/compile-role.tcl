package provide CompileRole 1.0

package require confutil
package require AppDetecter

namespace eval ::CompileRole {
  set role MYSQLD
}


proc ::CompileRole::run {} {
  variable role
  1,create tmp file, mkdir -p /opt/install-tmp, cd /opt/install-tmp
  1, curl -O http://www.fh.gov.cn/mysql-cluster-gpl-7.4.10.tar.gz
  yum install -y cmake.x86_64 cmake-fedora.noarch cmake-gui gcc.x86_64 gcc-c++.x86_64 cmake.x86_64 boost-devel.x86_64 cpan ncurses-devel libaio-devel
  install java
  cmake . -DWITH_BOOST=/usr/include/boost #cmake/build_configurations/mysql_release.cmake
  make
}

cmake . -L
cmake . -LH
cmake . -LA

ccmake .

make package ,create tar.gz file.
make install
make test

Management nodes:
1 ndb_mgmd and ndb_mgm

Data nodes:
ndbd or ndbmtd.
