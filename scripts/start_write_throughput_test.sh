#!/bin/bash
source /etc/profile
tidb_host=$1
pd_host=$2
thread=$3
ticat write_throughput.run h=${tidb_host} p=4000 pp=2379 ph=${pd_host} d=300 cp=/htap_test/benchbase  br_storage='s3\://benchmark/sysbench-1T-1ktable-3000krow-1tiflash' t=${thread} tn=1000 ts=3000000 : write_throughput.record cp=/htap_test/benchbase