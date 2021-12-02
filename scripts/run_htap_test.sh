#!/bin/bash
tcctl testbed create -f htap_test/config/tidb.yaml -r http://rms.pingcap.net:30007

namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep htap-test-tidb |awk '{print $1}')
pd_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/htap-test-pd-0 -owide | grep htap-test-pd-0 | awk '{print $6}')
tidb_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/htap-test-tidb-0 -owide | grep htap-test-tidb-0 | awk '{print $6}')


KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it htap-test-tiflash-0 -- mkdir /htap_test

KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/init.sh htap-test-tiflash-0:/htap_test
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/start.sh htap-test-tiflash-0:/htap_test

KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it htap-test-tiflash-0 -- sh /htap_test/init.sh

KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/table_statics/benchbase_table_static.tar.gz htap-test-tiflash-0:/htap_test/benchbase
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it htap-test-tiflash-0 -- tar zxvf /htap_test/benchbase/benchbase_table_static.tar.gz -C /htap_test/benchbase

KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it htap-test-tiflash-0 -- sh /htap_test/start.sh ${tidb_host} ${pd_host}

mkdir record/
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap-test-tiflash-0:/htap_test/benchbase/record/ch_benchmark_test.txt record/ch_benchmark_test.txt
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap-test-tiflash-0:/htap_test/benchbase/record/ch_benchmark_small_query_test.txt record/ch_benchmark_small_query_test.txt

tcctl testbed delete ${namespace} -r http://rms.pingcap.net:30007