terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC that will host the file system"
  type        = string
}

variable "subnet_ids" {
  description = "Two private subnet IDs in different Availability Zones"
  type        = list(string)
}

variable "client_cidr_blocks" {
  description = "CIDR blocks of NFS and management clients"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "fsx_admin_password" {
  description = "Password for the fsxadmin user"
  type        = string
  sensitive   = true
}

module "fsx_ontap" {
  source = "../.."

  name             = "example-ontap"
  storage_capacity = 1024
  subnet_ids       = var.subnet_ids

  deployment_type     = "MULTI_AZ_1"
  preferred_subnet_id = var.subnet_ids[0]
  throughput_capacity = 128

  fsx_admin_password = var.fsx_admin_password

  create_security_group              = true
  vpc_id                             = var.vpc_id
  security_group_enabled_protocols   = ["management", "nfs"]
  security_group_allowed_cidr_blocks = var.client_cidr_blocks

  storage_virtual_machines = {
    svm1 = {
      root_volume_security_style = "UNIX"
    }
  }

  volumes = {
    data = {
      svm_key           = "svm1"
      size_in_megabytes = 102400
      junction_path     = "/data"
      security_style    = "UNIX"
      tiering_policy = {
        name           = "AUTO"
        cooling_period = 31
      }
    }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "file_system_id" {
  value = module.fsx_ontap.id
}

output "svm_endpoints" {
  value = module.fsx_ontap.storage_virtual_machine_endpoints
}
