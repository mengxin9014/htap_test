#!/bin/bash

function scale_tiflash() {
    local replicas_inteval=$1
    current_replicas=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod  -owide | grep tiflash | wc -l)
    target_replicas=$(expr $current_replicas + $replicas_inteval)
    cat htap_test/config/scale_tiflash.yaml | sed "s/replicas: .*/replicas: $target_replicas/g" > htap_test/config/scale_tiflash_temp.yaml
    KUBECONFIG=kubeconfig.yml kubectl apply -f htap_test/config/scale_tiflash_temp.yaml

    current_replicas=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod  -owide | grep tiflash | wc -l)
    status=$(KUBECONFIG=kubeconfig.yml kubectl get tidbcluster stability-test -n ${namespace} | awk '{print $2}' | sed -n '2p')
    while [ $current_replicas -ne $target_replicas ] && [ $status != "True" ]
    do
      echo wait scale tiflash.
      sleep 10
      status=$(KUBECONFIG=kubeconfig.yml kubectl get tidbcluster stability-test -n ${namespace} | awk '{print $2}' | sed -n '2p')
    done
    echo scale tiflash success.
}

function restart_tiflash() {
    restart_time=$(date -u "+tidb.pingcap.com\/restartedAt: %Y-%m-%dT%H:%M")
    replicas=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod  -owide | grep tiflash | wc -l)
    cat htap_test/config/restart_tiflash.yaml | sed "s/restart_time/$restart_time/g" | sed "s/replicas: .*/replicas: $replicas/g" > htap_test/config/restart_tiflash_temp.yaml
    KUBECONFIG=kubeconfig.yml kubectl apply -f htap_test/config/restart_tiflash_temp.yaml
    status=$(KUBECONFIG=kubeconfig.yml kubectl get tidbcluster stability-test -n ${namespace} | awk '{print $2}' | sed -n '2p')
    while [ $status != "False" ]
    do
      echo wait restart start.
      sleep 2
      status=$(KUBECONFIG=kubeconfig.yml kubectl get tidbcluster stability-test -n ${namespace} | awk '{print $2}' | sed -n '2p')
    done
    while [ $status != "True" ]
    do
      echo wait restart finish.
      sleep 2
      status=$(KUBECONFIG=kubeconfig.yml kubectl get tidbcluster stability-test -n ${namespace} | awk '{print $2}' | sed -n '2p')
    done
    echo tiflash restart finish.
}

function wait_tiflash_region_balance() {
    sleep 10
    operator_info=$(KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- pd-ctl operator show -u http://${pd_host}:2379 | xargs echo)
    while [ ${#operator_info} -ne 3 ]
    do
      echo wait balance region.
      sleep 10
      operator_info=$(KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- pd-ctl operator show -u http://${pd_host}:2379)
    done
    echo balance region finish.
}

function kill_tiflash() {
    replicas=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod  -owide | grep tiflash | wc -l)
    pod_name=stability-test-tiflash-$(expr $replicas - 1)
    pid=$(KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it ${pod_name} -- ps -ef | grep 'tiflash server' | grep -v grep | awk '{print $2}')
    KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- kill -9 ${pid}
}

base_dir="/stability_test"
record_dir="stability_test_record"
mkdir $record_dir

query=Q7
thread=1

namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep stability-test-tidb | awk '{print $1}')
while [ "${namespace}" != "" ]
do
  echo wait ${namespace} be deleted.
  sleep 1
  namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep stability-test-tidb |awk '{print $1}')
done

tcctl testbed create -f htap_test/config/stability_test_tidb.yaml -r http://rms.pingcap.net:30007

namespace=$(tcctl testbed list -r http://rms.pingcap.net:30007 | grep stability-test-tidb |awk '{print $1}')
pd_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/stability-test-pd-0 -owide | grep stability-test-pd-0 | awk '{print $6}')
tidb_host=$(KUBECONFIG=kubeconfig.yml  kubectl -n ${namespace} get pod/stability-test-tidb-0 -owide | grep stability-test-tidb-0 | awk '{print $6}')


# init
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- mkdir $base_dir
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/init_stability_test.sh stability-test-tiflash-0:$base_dir
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/scripts/start_stability_test.sh stability-test-tiflash-0:$base_dir
sleep 2
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- sh $base_dir/init_stability_test.sh ${base_dir} ${pd_host}
if [ ${?} -ne 0 ]
then
  echo init failed.
  exit 1
fi
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/resource/querys_map.txt stability-test-tiflash-0:$base_dir/benchbase/querys_map.txt
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp htap_test/table_statics/benchbase_table_static.tar.gz stability-test-tiflash-0:$base_dir/benchbase
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- tar zxvf $base_dir/benchbase/benchbase_table_static.tar.gz -C $base_dir/benchbase


#scale_out case
scale_tiflash 2
wait_tiflash_region_balance
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- sh $base_dir/start_stability_test.sh ${base_dir} ${tidb_host} ${pd_host} ${query} ${thread} 's3\://benchmark/chbench_1T'
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp stability-test-tiflash-0:$base_dir/benchbase/record/ch_benchmark_test.txt $record_dir/ch_benchmark_test_q_${query}_t_${thread}_scale_tiflash_2.txt

#scale_in case
scale_tiflash -2
wait_tiflash_region_balance
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- sh $base_dir/start_stability_test.sh ${base_dir} ${tidb_host} ${pd_host} ${query} ${thread} 'none'
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp stability-test-tiflash-0:$base_dir/benchbase/record/ch_benchmark_test.txt $record_dir/ch_benchmark_test_q_${query}_t_${thread}_scale_tiflash_-2.txt

#restart case
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- sh $base_dir/start_stability_test.sh ${base_dir} ${tidb_host} ${pd_host} ${query} ${thread} 'none'
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp stability-test-tiflash-0:$base_dir/benchbase/record/ch_benchmark_test.txt $record_dir/ch_benchmark_test_q_${query}_t_${thread}_before_restart_tiflash.txt
restart_tiflash
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- sh $base_dir/start_stability_test.sh ${base_dir} ${tidb_host} ${pd_host} ${query} ${thread} 'none'
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp stability-test-tiflash-0:$base_dir/benchbase/record/ch_benchmark_test.txt $record_dir/ch_benchmark_test_q_${query}_t_${thread}_after_restart_tiflash.txt

#breakdown case
tables="CUSTOMER ITEM HISTORY DISTRICT NEW_ORDER OORDER ORDER_LINE STOCK WAREHOUSE nation region supplier"
for table in $tables
do
  mysql --host ${tidb_host} --port 4000 -u root -e "alter table ${table} set tiflash replica 2"
done
wait_tiflash_region_balance
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- sh $base_dir/start_stability_test.sh ${base_dir} ${tidb_host} ${pd_host} ${query} ${thread} 'none'
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp stability-test-tiflash-0:$base_dir/benchbase/record/ch_benchmark_test.txt $record_dir/ch_benchmark_test_q_${query}_t_${thread}_before_breakdown_tiflash.txt
kill_tiflash
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} exec -it stability-test-tiflash-0 -- sh $base_dir/start_stability_test.sh ${base_dir} ${tidb_host} ${pd_host} ${query} ${thread} 'none'
KUBECONFIG=kubeconfig.yml kubectl -n ${namespace} cp stability-test-tiflash-0:$base_dir/benchbase/record/ch_benchmark_test.txt $record_dir/ch_benchmark_test_q_${query}_t_${thread}_after_breakdown_tiflash.txt

tcctl testbed delete ${namespace} -r http://rms.pingcap.net:30007