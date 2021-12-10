#!/bin/bash

base_dir="/write_throughput_test"
record_dir="write_throughput_record"
mkdir $record_dir

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

    cat htap_test/config/write_throughput_test_tidb.yaml | sed "62s/replicas: .*/replicas: ${kv}/g" | sed "97s/replicas: .*/replicas: ${flash}/g" > htap_test/config/write_throughput_test_tidb_${kv}_${flash}.yaml

    tcctl testbed create -f htap_test/config/write_throughput_test_tidb_${kv}_${flash}.yaml -r http://rms.pingcap.net:30007

    namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep write-throughput-test-tidb |awk '{print $1}')
    pd_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/write-throughput-test-pd-0 -owide | grep write-throughput-test-pd-0 | awk '{print $6}')
    tidb_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/write-throughput-test-tidb-0 -owide | grep write-throughput-test-tidb-0 | awk '{print $6}')

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- mkdir $base_dir

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/init_write_throughput_test.sh write-throughput-test-tiflash-0:$base_dir
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/start_write_throughput_test.sh write-throughput-test-tiflash-0:$base_dir

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- sh $base_dir/init_write_throughput_test.sh ${base_dir}

    if [ ${?} -ne 0 ]
    then
      echo init failed.
      exit 1
    fi

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/table_statics/benchbase_table_static.tar.gz write-throughput-test-tiflash-0:$base_dir/benchbase
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- tar zxvf $base_dir/benchbase/benchbase_table_static.tar.gz -C $base_dir/benchbase

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it write-throughput-test-tiflash-0 -- sh $base_dir/start_write_throughput_test.sh ${base_dir} ${tidb_host} ${pd_host} ${thread}

    if [ ${?} -ne 0 ]
    then
      echo start failed.
      exit 1
    fi

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp write-throughput-test-tiflash-0:$base_dir/benchbase/record/write_throughput_test.txt $record_dir/write_throughput_test_tikv_${kv}_tiflash_${flash}_t_${thread}.txt

    tcctl testbed delete ${namespace} -r http://rms.pingcap.net:30007

  done
done
