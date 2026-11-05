# terraform-aws-fsx-ontap

Terraform module for Amazon FSx for NetApp ONTAP: file system, storage virtual machines with optional Active Directory join, volumes with tiering, and protocol-aware security groups.

[![Validate](https://github.com/pankajrudrawar/terraform-aws-fsx-ontap/actions/workflows/validate.yml/badge.svg)](https://github.com/pankajrudrawar/terraform-aws-fsx-ontap/actions/workflows/validate.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Terraform](https://img.shields.io/badge/terraform-%E2%89%A5%201.5.7-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-module-FF9900)

## Features

- Single-AZ and multi-AZ deployments, including HA pairs on second-generation types
- Storage virtual machines defined as a map, with optional self-managed Active Directory join
- Volumes with tiering policy, snapshot policy and storage efficiency
- Security group built from protocol groups (`management`, `nfs`, `smb`, `iscsi`, `snapmirror`)
- Passwords are passed as separate `sensitive` variables so the rest of each object stays visible in plans
- Plan-time checks for subnet counts and HA pair and throughput combinations

## Usage

```hcl
module "fsx_ontap" {
  source = "github.com/pankajrudrawar/terraform-aws-fsx-ontap"

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
```

A complete, runnable configuration is in [`examples/basic`](examples/basic).

## Notes

- Passwords supplied to this module end up in Terraform state. Use an encrypted remote backend and restrict access to it.
- For second-generation deployments set `throughput_capacity_per_ha_pair` and `ha_pairs`; `throughput_capacity` is then ignored.
- SnapMirror between clusters needs the `snapmirror` protocol group opened to the peer cluster's CIDR.

## Module reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.7 |
| aws | >= 5.40 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create | Controls whether any resources are created by this module | `bool` | `true` | no |
| name | Name of the file system, used for the Name tag and the security group name | `string` | n/a | yes |
| storage_capacity | SSD storage capacity in GiB, 1024 to 196608 | `number` | `1024` | no |
| subnet_ids | Subnet IDs. One for single-AZ deployments, two for multi-AZ deployments | `list(string)` | n/a | yes |
| preferred_subnet_id | Subnet of the preferred (active) file server. Defaults to the first entry of `subnet_ids` | `string` | `null` | no |
| deployment_type | Deployment type: `SINGLE_AZ_1`, `SINGLE_AZ_2`, `MULTI_AZ_1` or `MULTI_AZ_2` | `string` | `"MULTI_AZ_1"` | no |
| throughput_capacity | Throughput capacity in MBps for the file system. Ignored when `throughput_capacity_per_ha_pair` is set | `number` | `128` | no |
| throughput_capacity_per_ha_pair | Throughput capacity in MBps per HA pair. Use with `ha_pairs` on second-generation deployment types | `number` | `null` | no |
| ha_pairs | Number of HA pairs for second-generation deployment types | `number` | `null` | no |
| fsx_admin_password (sensitive) | Password for the `fsxadmin` ONTAP user. Leave null to keep the account locked | `string` | `null` | no |
| route_table_ids | Route table IDs that receive the floating endpoint route. Used by multi-AZ deployments | `list(string)` | `null` | no |
| endpoint_ip_address_range | CIDR range for the multi-AZ floating endpoints. Uses an unused range inside 198.19.0.0/16 when null | `string` | `null` | no |
| storage_type | Storage type of the primary tier. `SSD` is the only value currently supported | `string` | `"SSD"` | no |
| disk_iops_configuration | SSD IOPS settings. `mode` is `AUTOMATIC` or `USER_PROVISIONED`; `iops` is only used with `USER_PROVISIONED` | `object` | `null` | no |
| kms_key_id | ARN of the KMS key used for encryption at rest. Uses the AWS-managed key when null | `string` | `null` | no |
| automatic_backup_retention_days | Days to retain automatic backups, 0 to 90. Use 0 to disable | `number` | `30` | no |
| daily_automatic_backup_start_time | Daily backup start time in `HH:MM` UTC | `string` | `null` | no |
| weekly_maintenance_start_time | Preferred weekly maintenance window start in `d:HH:MM` UTC, where d is 1 (Monday) to 7 (Sunday) | `string` | `null` | no |
| storage_virtual_machines | Map of storage virtual machines (SVMs) keyed by an arbitrary static name. Passwords are supplied separately through `svm_admin_passwords` and `svm_active_directory_passwords` | `map(object)` | `{}` | no |
| svm_admin_passwords (sensitive) | Map of `vsadmin` passwords keyed by the `storage_virtual_machines` key | `map(string)` | `{}` | no |
| svm_active_directory_passwords (sensitive) | Map of Active Directory service account passwords keyed by the `storage_virtual_machines` key | `map(string)` | `{}` | no |
| volumes | Map of volumes keyed by an arbitrary static name. `svm_key` must match a key in `storage_virtual_machines` | `map(object)` | `{}` | no |
| create_security_group | Whether to create a security group for the file system | `bool` | `true` | no |
| security_group_name | Name of the security group. Defaults to `name` | `string` | `null` | no |
| security_group_description | Description of the security group | `string` | see `variables.tf` | no |
| vpc_id | ID of the VPC in which to create the security group. Required when `create_security_group` is true | `string` | `null` | no |
| security_group_enabled_protocols | Protocol groups to open to `security_group_allowed_cidr_blocks`. Any of `management`, `nfs`, `smb`, `iscsi`, `snapmirror` | `list(string)` | `["management"]` | no |
| security_group_allowed_cidr_blocks | IPv4 CIDR blocks that may reach the protocols listed in `security_group_enabled_protocols` | `list(string)` | `[]` | no |
| security_group_ids | Additional existing security group IDs to attach to the file system | `list(string)` | `[]` | no |
| tags | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| id | ID of the file system |
| arn | ARN of the file system |
| dns_name | DNS name of the file system |
| endpoints | Management and intercluster endpoints of the file system |
| network_interface_ids | IDs of the network interfaces created for the file system |
| storage_virtual_machine_ids | Map of SVM IDs keyed by the `storage_virtual_machines` key |
| storage_virtual_machine_endpoints | Map of SVM data and management endpoints (iSCSI, NFS, SMB, management) keyed by the `storage_virtual_machines` key |
| volume_ids | Map of volume IDs keyed by the `volumes` key |
| volume_arns | Map of volume ARNs keyed by the `volumes` key |
| security_group_id | ID of the security group created by this module |
<!-- END_TF_DOCS -->

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first, and ask questions in [Discussions](https://github.com/pankajrudrawar/terraform-aws-fsx-ontap/discussions). Run `pre-commit run -a` before opening a pull request. It formats the code, validates it, runs TFLint and refreshes the reference tables above with terraform-docs.

Security problems should be reported privately. See [SECURITY.md](SECURITY.md).

## License

Apache 2.0. See [LICENSE](LICENSE).
