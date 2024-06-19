#!/bin/bash
# Description: This script automates the deployment, scaling, benchmarking, and destruction of HDInsight clusters using Terraform.
# It applies the Terraform configuration with an initial number of worker nodes and HDInsight/Hadoop versions,
# scales the cluster, runs the HiBench benchmark 10 times for each deployment and environment size, and then destroys the Terraform-managed infrastructure.

set -e

log() {
  local message=$1
  echo "$(date +"%Y-%m-%d %H:%M:%S") - ${message}"
}

scale_hdinsight_cluster() {
  local resource_group=$1
  local cluster_name=$2
  local target_instance_count=$3

  log "Scaling HDInsight cluster to ${target_instance_count} worker nodes"
  az hdinsight resize --resource-group ${resource_group} --name ${cluster_name} --workernode-count ${target_instance_count}
  log "Scaling operation completed"
}

run_hibench_benchmark() {
  local hibench_data_size=$1

  for i in {1..10}; do
    log "Running hibench benchmark iteration $i with data size ${hibench_data_size}"
    ansible-playbook hibench/main.yml -i hibench/hosts.ini -e "number_of_workers=${NUMBER_OF_WORKERS} hibench_data_size=${hibench_data_size}"
  done
  log "Completed running hibench benchmark 10 times with data size ${hibench_data_size}"
}

benchmark_terraform_HDI() {
  local hdinsight_version=$1
  local hadoop_version=$2
  local resource_group=$3
  local cluster_name=$4
  local initial_worker_count=1

  export NUMBER_OF_WORKERS=${initial_worker_count}

  log "Starting initial deployment for HDInsight_version=${hdinsight_version}, hadoop_version=${hadoop_version}, number_of_workers=${initial_worker_count}"
  cd deployment
  terraform apply -auto-approve -var="HDInsight_version=${hdinsight_version}" -var="number_of_workers=${initial_worker_count}" -var="hadoop_version=${hadoop_version}"
  log "Terraform apply completed for HDInsight_version=${hdinsight_version}, hadoop_version=${hadoop_version}, number_of_workers=${initial_worker_count}"
  cd ..

  for hibench_data_size in small large huge; do
    run_hibench_benchmark ${hibench_data_size}
  done

  for number_of_workers in 4 6 8; do
    export NUMBER_OF_WORKERS=${number_of_workers}

    scale_hdinsight_cluster ${resource_group} ${cluster_name} ${number_of_workers}

    hibench/create-inventory.sh

    for hibench_data_size in small large huge; do
      run_hibench_benchmark ${hibench_data_size}
    done
  done

  log "Running terraform destroy"
  cd deployment
  terraform destroy -auto-approve
  cd ..
  log "terraform destroy completed"
}

# Initial deployment for HDInsight version 4.0
log "Starting initial deployments for HDInsight version 4.0"
benchmark_terraform_HDI 4.0 3.1 AlexGuttenberger_Thesis hadoopcluster12312BerlinABC
log "Initial deployments for HDInsight version 4.0 completed"

# Deployments for HDInsight version 5.1
log "Starting deployments for HDInsight version 5.1"
benchmark_terraform_HDI 5.1 3.3 AlexGuttenberger_Thesis hadoopcluster12312BerlinABC
log "Deployments for HDInsight version 5.1 completed"

log "All deployments completed successfully"
