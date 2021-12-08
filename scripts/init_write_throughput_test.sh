#!/bin/bash

cd /htap_test

yum -y install wget
yum -y install git
yum -y install make
yum -y install tar
yum -y install mysql
curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.rpm.sh | bash
yum -y install sysbench

wget https://studygolang.com/dl/golang/go1.17.3.linux-amd64.tar.gz
tar -zxvf go1.17.3.linux-amd64.tar.gz
mv go /usr/local
echo "export GOROOT=/usr/local/go" >> /etc/profile
echo "export GOPATH=/home/gopath" >> /etc/profile
echo "export GOBIN=/home/gopath/bin" >> /etc/profile
echo "export GOPROXY=https://goproxy.io,direct" >> /etc/profile
echo "export PATH=\$PATH:\$GOROOT/bin:\$GOBIN" >> /etc/profile

wget https://download.oracle.com/java/17/archive/jdk-17.0.1_linux-x64_bin.tar.gz
tar -zxvf jdk-17.0.1_linux-x64_bin.tar.gz
mv  jdk-17.0.1 /usr/local/java
echo "export JAVA_HOME=/usr/local/java" >> /etc/profile
echo "JRE_HOME=\${JAVA_HOME}/jre" >> /etc/profile
echo "export CLASSPATH=.:\${JAVA_HOME}/lib:\${JRE_HOME}/lib" >> /etc/profile
echo "export PATH=\${JAVA_HOME}/bin:\$PATH" >> /etc/profile

source /etc/profile

git clone https://github.com/innerr/ticat
cd ticat
make
mv bin/ticat /usr/local/bin/
ticat hub.add innerr/tidb.ticat
ticat hub.add mengxin9014/chbenchmark.tidb.ticat
cd ..

wget  https://github.com/mengxin9014/benchbase/releases/download/v2021/benchbase.tgz
tar -zxvf  benchbase.tgz
mv benchbase-2021-SNAPSHOT benchbase

wget https://download.pingcap.org/tidb-toolkit-v5.2.2-linux-amd64.tar.gz
tar zxvf tidb-toolkit-v5.2.2-linux-amd64.tar.gz
mv tidb-toolkit-v5.2.2-linux-amd64/bin/br /usr/local/bin/
