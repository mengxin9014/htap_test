#!/bin/bash

base_dir="/htap_test"
record_dir="htap_test_record"
mkdir $record_dir || true

ap_threads="1 5 10 20 30"
for thread in $ap_threads
do
  if [ ${thread} -ne 1 ]
  then
    querys="Q6 Q12 Q13 Q14"
  else
    querys="Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10 Q11 Q12 Q13 Q14 Q15 Q16 Q17 Q18 Q19 Q20 Q21 Q22"
  fi

  for query in $querys
  do
    namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep htap-test-tidb | awk '{print $1}')
    while [ "${namespace}" != "" ]
    do
      echo wait ${namespace} be deleted.
      sleep 1
      namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep htap-test-tidb |awk '{print $1}')
    done

    tcctl testbed create -f htap_test/config/htap_test_tidb.yaml -r http://rms.pingcap.net:30007

    namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep htap-test-tidb |awk '{print $1}')
    pd_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/htap-test-pd-0 -owide | grep htap-test-pd-0 | awk '{print $6}')
    tidb_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/htap-test-tidb-0 -owide | grep htap-test-tidb-0 | awk '{print $6}')


    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it htap-test-tiflash-0 -- mkdir $base_dir

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/init_htap_test.sh htap-test-tiflash-0:$base_dir
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/start_htap_test.sh htap-test-tiflash-0:$base_dir

    sleep 2
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it htap-test-tiflash-0 -- sh $base_dir/init_htap_test.sh ${base_dir}

    if [ ${?} -ne 0 ]
    then
      echo init failed.
      exit 1
    fi

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/resource/querys_map.txt htap-test-tiflash-0:$base_dir/benchbase/querys_map.txt

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/table_statics/benchbase_table_static.tar.gz htap-test-tiflash-0:$base_dir/benchbase
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it htap-test-tiflash-0 -- tar zxvf $base_dir/benchbase/benchbase_table_static.tar.gz -C $base_dir/benchbase

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it htap-test-tiflash-0 -- sh $base_dir/start_htap_test.sh ${base_dir} ${tidb_host} ${pd_host} ${query} ${thread}

    if [ ${?} -ne 0 ]
    then
      echo start failed.
      exit 1
    fi

    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap-test-tiflash-0:$base_dir/benchbase/record/ch_benchmark_test.txt $record_dir/ch_benchmark_test_q_${query}_t_${thread}.txt

    tcctl testbed delete ${namespace} -r http://rms.pingcap.net:30007

  done
done