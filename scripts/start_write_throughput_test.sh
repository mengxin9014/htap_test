#!/bin/bash
set -eo pipefail

source /etc/profile
base_dir=$1
tidb_host=$2
pd_host=$3
thread=$4
ticat write_throughput.run h=${tidb_host} p=4000 pp=2379 ph=${pd_host} d=300 cp=${base_dir}/benchbase  br_storage='s3\://benchmark/sysbench-1T-1ktable-3000krow-1tiflash' t=${thread} tn=1000 ts=3000000 : write_throughput.record cp=${base_dir}/benchbase