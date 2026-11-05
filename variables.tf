variable "create" {
  description = "Controls whether any resources are created by this module"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the file system, used for the Name tag and the security group name"
  type        = string
}

variable "storage_capacity" {
  description = "SSD storage capacity in GiB, 1024 to 196608"
  type        = number
  default     = 1024
}

variable "subnet_ids" {
  description = "Subnet IDs. One for single-AZ deployments, two for multi-AZ deployments"
  type        = list(string)
}

variable "preferred_subnet_id" {
  description = "Subnet of the preferred (active) file server. Required for multi-AZ deployments"
  type        = string
  default     = null
}

variable "deployment_type" {
  description = "Deployment type: `SINGLE_AZ_1`, `SINGLE_AZ_2`, `MULTI_AZ_1` or `MULTI_AZ_2`"
  type        = string
  default     = "MULTI_AZ_1"

  validation {
    condition     = contains(["SINGLE_AZ_1", "SINGLE_AZ_2", "MULTI_AZ_1", "MULTI_AZ_2"], var.deployment_type)
    error_message = "deployment_type must be SINGLE_AZ_1, SINGLE_AZ_2, MULTI_AZ_1 or MULTI_AZ_2."
  }
}

variable "throughput_capacity" {
  description = "Throughput capacity in MBps for the file system. Ignored when `throughput_capacity_per_ha_pair` is set"
  type        = number
  default     = 128
}

variable "throughput_capacity_per_ha_pair" {
  description = "Throughput capacity in MBps per HA pair. Use with `ha_pairs` on second-generation deployment types"
  type        = number
  default     = null
}

variable "ha_pairs" {
  description = "Number of HA pairs for second-generation deployment types"
  type        = number
  default     = null
}

variable "fsx_admin_password" {
  description = "Password for the `fsxadmin` ONTAP user. Leave null to keep the account locked"
  type        = string
  default     = null
  sensitive   = true
}

variable "route_table_ids" {
  description = "Route table IDs that receive the floating endpoint route. Used by multi-AZ deployments"
  type        = list(string)
  default     = null
}

variable "endpoint_ip_address_range" {
  description = "CIDR range for the multi-AZ floating endpoints. Uses an unused range inside 198.19.0.0/16 when null"
  type        = string
  default     = null
}

variable "storage_type" {
  description = "Storage type of the primary tier. `SSD` is the only value currently supported"
  type        = string
  default     = "SSD"
}

variable "disk_iops_configuration" {
  description = "SSD IOPS settings. `mode` is `AUTOMATIC` or `USER_PROVISIONED`; `iops` is only used with `USER_PROVISIONED`"
  type = object({
    mode = optional(string, "AUTOMATIC")
    iops = optional(number)
  })
  default = null
}

variable "kms_key_id" {
  description = "ARN of the KMS key used for encryption at rest. Uses the AWS-managed key when null"
  type        = string
  default     = null
}

variable "automatic_backup_retention_days" {
  description = "Days to retain automatic backups, 0 to 90. Use 0 to disable"
  type        = number
  default     = 30
}

variable "daily_automatic_backup_start_time" {
  description = "Daily backup start time in `HH:MM` UTC"
  type        = string
  default     = null
}

variable "weekly_maintenance_start_time" {
  description = "Preferred weekly maintenance window start in `d:HH:MM` UTC, where d is 1 (Monday) to 7 (Sunday)"
  type        = string
  default     = null
}

################################################################################
# Storage virtual machines and volumes
################################################################################

variable "storage_virtual_machines" {
  description = "Map of storage virtual machines (SVMs) keyed by an arbitrary static name. Passwords are supplied separately through `svm_admin_passwords` and `svm_active_directory_passwords`"
  type = map(object({
    name                       = optional(string)
    root_volume_security_style = optional(string)
    active_directory = optional(object({
      netbios_name                           = string
      domain_name                            = string
      username                               = string
      dns_ips                                = list(string)
      file_system_administrators_group       = optional(string)
      organizational_unit_distinguished_name = optional(string)
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "svm_admin_passwords" {
  description = "Map of `vsadmin` passwords keyed by the `storage_virtual_machines` key"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "svm_active_directory_passwords" {
  description = "Map of Active Directory service account passwords keyed by the `storage_virtual_machines` key"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "volumes" {
  description = "Map of volumes keyed by an arbitrary static name. `svm_key` must match a key in `storage_virtual_machines`"
  type = map(object({
    svm_key                    = string
    name                       = optional(string)
    size_in_megabytes          = number
    junction_path              = optional(string)
    security_style             = optional(string)
    ontap_volume_type          = optional(string)
    volume_style               = optional(string)
    snapshot_policy            = optional(string)
    storage_efficiency_enabled = optional(bool, true)
    copy_tags_to_backups       = optional(bool, true)
    skip_final_backup          = optional(bool, true)
    tiering_policy = optional(object({
      name           = string
      cooling_period = optional(number)
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# Security group
################################################################################

variable "create_security_group" {
  description = "Whether to create a security group for the file system"
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Name of the security group. Defaults to `name`"
  type        = string
  default     = null
}

variable "security_group_description" {
  description = "Description of the security group"
  type        = string
  default     = "Security group for the FSx for NetApp ONTAP file system"
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the security group. Required when `create_security_group` is true"
  type        = string
  default     = null
}

variable "security_group_enabled_protocols" {
  description = "Protocol groups to open to `security_group_allowed_cidr_blocks`. Any of `management`, `nfs`, `smb`, `iscsi`, `snapmirror`"
  type        = list(string)
  default     = ["management"]

  validation {
    condition     = length(setsubtract(var.security_group_enabled_protocols, ["management", "nfs", "smb", "iscsi", "snapmirror"])) == 0
    error_message = "security_group_enabled_protocols may only contain management, nfs, smb, iscsi and snapmirror."
  }
}

variable "security_group_allowed_cidr_blocks" {
  description = "IPv4 CIDR blocks that may reach the protocols listed in `security_group_enabled_protocols`"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Additional existing security group IDs to attach to the file system"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
