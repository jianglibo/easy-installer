## Usage

* tclsh easy-installer.tcl --host=10.74.111.70 --profile=standalone solr install
* tclsh easy-installer.tcl --host=10.74.111.70 --mocklist=office.txt solr install
* tclsh easy-installer.tcl --host=10.74.111.70 --mocklist=office.txt solr create --core=xxx --condir=yyy --profile=standardalone

## solr-cloud
found zookeeper in hbase-site.xml,
nn.intranet.fh.gov.cn,dn1.intranet.fh.gov.cn,dn2.intranet.fh.gov.cn,dn3.intranet.fh.gov.cn,snn.intranet.fh.gov.cn

server/scripts/cloud-scripts/zkcli.sh -zkhost nn.intranet.fh.gov.cn,dn1.intranet.fh.gov.cn,dn2.intranet.fh.gov.cn,dn3.intranet.fh.gov.cn,snn.intranet.fh.gov.cn -cmd makepath /solr

./bin/solr create_collection -c gettingstarted -d sample_techproducts_configs -n sample_techproducts_configs_right -shards 2 -replicationFactor 2

Subject Alternative Name (SAN)，允许多个域名匹配

keytool -genkeypair -alias solr-ssl -keyalg RSA -keysize 2048 -keypass secret -storepass secret -validity 9999 -keystore solr-ssl.keystore.jks -ext SAN=DNS:localhost,IP:192.168.1.3,IP:127.0.0.1 -dname "CN=localhost, OU=Organizational Unit, O=Organization, L=Location, ST=State, C=Country"

invoke：
keytool -genkeypair -alias solr-ssl -keyalg RSA -keysize 2048 -keypass secret -storepass secret -validity 9999 -keystore solr-ssl.keystore.jks -ext SAN=DNS:localhost,DNS:che.intranet.fh.gov.cn,IP:10.74.111.70,IP:127.0.0.1 -dname "CN=solrcloud, OU=fhgov, O=xxzx, L=fenghua, ST=zj, C=cn"

got：solr-ssl.keystore.jks

First convert the JKS keystore into PKCS12 format using keytool:
keytool -importkeystore -srckeystore solr-ssl.keystore.jks -destkeystore solr-ssl.keystore.p12 -srcstoretype jks -deststoretype pkcs12 -destkeypass secretkeypass
# for curl to use
openssl pkcs12 -in solr-ssl.keystore.p12 -out solr-ssl.pem

# before start solrcloud

server/scripts/cloud-scripts/zkcli.sh -zkhost nn.intranet.fh.gov.cn,dn1.intranet.fh.gov.cn,dn2.intranet.fh.gov.cn,dn3.intranet.fh.gov.cn,snn.intranet.fh.gov.cn/solr -cmd clusterprop -name urlScheme -val https

locked:
/opt/hadoop-2.5.2/hadoop-2.5.2/bin/hdfs dfs -rm /solr/testlogshdfs11/core_node1/data/index/write.lock
