#!/bin/bash
set -eo pipefail

source /etc/profile
base_dir=$1
tidb_host=$2
pd_host=$3
query=$4
thread=$5
br_storage=$6
ticat chbench.run h=${tidb_host} p=4000 pp=2379 ph=${pd_host} sf=9000  d=300 cp=${base_dir}/benchbase  br_storage=${br_storage} q=${query} t=${thread} : chbench.record cp=${base_dir}/benchbase q=${query} t=${thread}