variable "HDInsight_version" {
  description = "Version of HDInsight"
  type        = string
  default     = "4.0"
}

variable "hadoop_version" {
  description = "Version of Hadoop of the HDInsight cluster, get it from HDInsight documentation"
  type        = string
  default     = "3.1"
}

variable "number_of_workers" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

## Example for creating new ressource group
# resource "azurerm_resource_group" "similarity_exp_rg" {
#   name     = "SimilarityExperimentRG" # Name of the resource group
#   location = "germanywestcentral" # Geographic location for the resources
# }

data "azurerm_resource_group" "similarity_exp_rg" {
  name     = "AlexGuttenberger_Thesis" # Name of the resource group
}

## Workaround for timeout bug when creating storage account
resource "random_string" "storage-suffix" {
  length  = 8
  special = false
}

# Storage Account for Similarity Experiment
resource "azurerm_storage_account" "similarity_exp_storage" {
  name                = "simexpstor${lower(random_string.storage-suffix.result)}" # workaround timeout bug
  ## use existing resource group instead
  # resource_group_name      = azurerm_resource_group.similarity_exp_rg.name
  # location                 = azurerm_resource_group.similarity_exp_rg.location
  resource_group_name      = data.azurerm_resource_group.similarity_exp_rg.name
  location                 = data.azurerm_resource_group.similarity_exp_rg.location
  account_tier             = "Standard" # Defines the tier
  account_replication_type = "LRS"
}

# Storage Container within the Storage Account
resource "azurerm_storage_container" "similarity_exp_container" {
  name                  = "simexpcontainer" # Container name
  storage_account_name  = azurerm_storage_account.similarity_exp_storage.name
  container_access_type = "private" # Access type set to private
}

## Password for admin dashboard
resource "random_password" "ambari-password" {
  length           = 12
  special          = true
  override_special = "_%@"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# HDInsight Hadoop Cluster Configuration for Similarity Experiment
resource "azurerm_hdinsight_hadoop_cluster" "similarity_exp_hadoop_cluster" {
  name                = "hadoopcluster12312BerlinABC"
  ## use exiting resource group instead
  # resource_group_name = azurerm_resource_group.similarity_exp_rg.name
  # location            = azurerm_resource_group.similarity_exp_rg.location
  resource_group_name = data.azurerm_resource_group.similarity_exp_rg.name
  location            = data.azurerm_resource_group.similarity_exp_rg.location
  tier                = "Standard"

  cluster_version     = var.HDInsight_version
  component_version {
    hadoop = var.hadoop_version
  }

  # Gateway configuration for the cluster
  gateway {
    username = "simexpusergw"
    password = "${random_password.ambari-password.result}" # Replace with a secure password
  }

  # Storage account configuration for the Hadoop cluster
  storage_account {
    storage_container_id = azurerm_storage_container.similarity_exp_container.id
    storage_account_key  = azurerm_storage_account.similarity_exp_storage.primary_access_key
    is_default           = true
  }

  # Configuration for the roles in the Hadoop cluster
  roles {
    # Head node configuration
    head_node {
      vm_size  = "Standard_A4_V2" # VM size for the head node
      username = "simexpuservm"
      ssh_keys = [local.ssh_public_key_content]
    }

    # Worker node configuration
    worker_node {
      vm_size  = "Standard_A2m_V2" # VM size for worker nodes
      username = "simexpuservm"
      ssh_keys = [local.ssh_public_key_content]
      target_instance_count = var.number_of_workers # Number of worker nodes
    }

    zookeeper_node {
      vm_size  = "Standard_A1_V2"
      username = "simexpuservm"
      ssh_keys = [local.ssh_public_key_content]
    }
  }
}
