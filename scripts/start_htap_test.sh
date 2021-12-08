#!/bin/bash
source /etc/profile
tidb_host=$1
pd_host=$2
query=$3
thread=$4
ticat chbench.run h=${tidb_host} p=4000 pp=2379 ph=${pd_host} d=300 sf=1 cp=/htap_test/benchbase  br_storage='s3\://benchmark/chbench_1T' q=${query} t=${thread} : chbench.record cp=/htap_test/benchbase q=${query} t=${thread}