output "id" {
  description = "ID of the file system"
  value       = try(aws_fsx_ontap_file_system.this[0].id, null)
}

output "arn" {
  description = "ARN of the file system"
  value       = try(aws_fsx_ontap_file_system.this[0].arn, null)
}

output "dns_name" {
  description = "DNS name of the file system"
  value       = try(aws_fsx_ontap_file_system.this[0].dns_name, null)
}

output "endpoints" {
  description = "Management and intercluster endpoints of the file system"
  value       = try(aws_fsx_ontap_file_system.this[0].endpoints, [])
}

output "network_interface_ids" {
  description = "IDs of the network interfaces created for the file system"
  value       = try(aws_fsx_ontap_file_system.this[0].network_interface_ids, [])
}

output "storage_virtual_machine_ids" {
  description = "Map of SVM IDs keyed by the `storage_virtual_machines` key"
  value       = { for k, v in aws_fsx_ontap_storage_virtual_machine.this : k => v.id }
}

output "storage_virtual_machine_endpoints" {
  description = "Map of SVM data and management endpoints (iSCSI, NFS, SMB, management) keyed by the `storage_virtual_machines` key"
  value       = { for k, v in aws_fsx_ontap_storage_virtual_machine.this : k => v.endpoints }
}

output "volume_ids" {
  description = "Map of volume IDs keyed by the `volumes` key"
  value       = { for k, v in aws_fsx_ontap_volume.this : k => v.id }
}

output "volume_arns" {
  description = "Map of volume ARNs keyed by the `volumes` key"
  value       = { for k, v in aws_fsx_ontap_volume.this : k => v.arn }
}

output "security_group_id" {
  description = "ID of the security group created by this module"
  value       = try(aws_security_group.this[0].id, null)
}
