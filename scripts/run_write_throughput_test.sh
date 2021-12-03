#!/bin/bash
tcctl testbed create -f write_throughput_test/config/write_throughput_test_tidb.yaml -r http://rms.pingcap.net:30007

namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep write-throughput-test-tidb |awk '{print $1}')
pd_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/write-throughput-test-pd-0 -owide | grep write-throughput-test-pd-0 | awk '{print $6}')
tidb_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/write-throughput-test-tidb-0 -owide | grep write-throughput-test-tidb-0 | awk '{print $6}')


KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- mkdir /write_throughput_test

KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp write_throughput_test/scripts/init_write_throughput_test.sh write-throughput-test-tiflash-0:/write_throughput_test
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp write_throughput_test/scripts/start_write_throughput_test.sh write-throughput-test-tiflash-0:/write_throughput_test

KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- sh /write_throughput_test/init_write_throughput_test.sh

KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp write_throughput_test/table_statics/benchbase_table_static.tar.gz write-throughput-test-tiflash-0:/write_throughput_test/benchbase
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- tar zxvf /write_throughput_test/benchbase/benchbase_table_static.tar.gz -C /write_throughput_test/benchbase

KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- sh /write_throughput_test/start_write_throughput_test.sh ${tidb_host} ${pd_host}

mkdir record/
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp write-throughput-test-tiflash-0:/write_throughput_test/benchbase/record/ch_benchmark_test.txt record/ch_benchmark_test.txt
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp write-throughput-test-tiflash-0:/write_throughput_test/benchbase/record/ch_benchmark_small_query_test.txt record/ch_benchmark_small_query_test.txt

tcctl testbed delete ${namespace} -r http://rms.pingcap.net:30007