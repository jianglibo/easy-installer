## Usage

* tclsh easy-installer.tcl --host=10.74.111.70 solr install
* tclsh easy-installer.tcl --host=10.74.111.70 --mocklist=office.txt solr install

## solr-cloud
found zookeeper in hbase-site.xml,
nn.intranet.fh.gov.cn,dn1.intranet.fh.gov.cn,dn2.intranet.fh.gov.cn,dn3.intranet.fh.gov.cn,snn.intranet.fh.gov.cn

server/scripts/cloud-scripts/zkcli.sh -zkhost nn.intranet.fh.gov.cn,dn1.intranet.fh.gov.cn,dn2.intranet.fh.gov.cn,dn3.intranet.fh.gov.cn,snn.intranet.fh.gov.cn -cmd makepath /solr
