#!/bin/bash

threads="1 2 4"
while [ $# -ge 1 ]
do
  kv_tiflash=(${1//// })
  kv=${kv_tiflash[0]}
  flash=${kv_tiflash[1]}
  shift

  for thread in $threads
  do
    namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep write-throughput-test-tidb |awk '{print $1}')
    while [ "${namespace}" != "" ]
    do
      echo wait ${namespace} be deleted.
      sleep 1
      namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep write-throughput-test-tidb |awk '{print $1}')
    done

    if [ ! -f "htap_test/config/write_throughput_test_tidb_${kv}_${flash}.yaml" ]
    then
      echo htap_test/config/write_throughput_test_tidb_${kv}_${flash}.yaml not exists, please create it.
      exit 1
    fi

    tcctl testbed create -f htap_test/config/write_throughput_test_tidb_${kv}_${flash}.yaml -r http://rms.pingcap.net:30007

    namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep write-throughput-test-tidb |awk '{print $1}')
    pd_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/write-throughput-test-pd-0 -owide | grep write-throughput-test-pd-0 | awk '{print $6}')
    tidb_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/write-throughput-test-tidb-0 -owide | grep write-throughput-test-tidb-0 | awk '{print $6}')

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- mkdir /write_throughput_test

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/init_write_throughput_test.sh write-throughput-test-tiflash-0:/write_throughput_test
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/start_write_throughput_test.sh write-throughput-test-tiflash-0:/write_throughput_test

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- sh /write_throughput_test/init_write_throughput_test.sh

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/table_statics/benchbase_table_static.tar.gz write-throughput-test-tiflash-0:/write_throughput_test/benchbase
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- tar zxvf /write_throughput_test/benchbase/benchbase_table_static.tar.gz -C /write_throughput_test/benchbase

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- sh /write_throughput_test/start_write_throughput_test.sh ${tidb_host} ${pd_host} ${thread}

    mkdir record/
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp write-throughput-test-tiflash-0:/write_throughput_test/benchbase/record/write_throughput_test.txt record/write_throughput_test_tikv_${kv}_tiflash_${flash}_t_${thread}.txt

    tcctl testbed delete ${namespace} -r http://rms.pingcap.net:30007

  done
done
