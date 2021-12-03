#!/bin/bash
source /etc/profile
tidb_host=$1
pd_host=$2
ticat chbench.run h=${tidb_host} p=4000 pp=2379 ph=${pd_host} sf=1 cp=/htap_test/benchbase  br_storage='s3\://benchmark/chbench_1T' : chbench.record cp=/htap_test/benchbase