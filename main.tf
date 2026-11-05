locals {
  create_security_group = var.create && var.create_security_group
  security_group_name   = coalesce(var.security_group_name, var.name)

  security_group_ids = concat(
    local.create_security_group ? [aws_security_group.this[0].id] : [],
    var.security_group_ids,
  )

  # Ports used by ONTAP data and management LIFs, grouped by protocol
  ontap_port_sets = {
    management = [
      { protocol = "tcp", from = 22, to = 22 },
      { protocol = "tcp", from = 443, to = 443 },
    ]
    nfs = [
      { protocol = "tcp", from = 111, to = 111 },
      { protocol = "udp", from = 111, to = 111 },
      { protocol = "tcp", from = 635, to = 635 },
      { protocol = "udp", from = 635, to = 635 },
      { protocol = "tcp", from = 2049, to = 2049 },
      { protocol = "udp", from = 2049, to = 2049 },
      { protocol = "tcp", from = 4045, to = 4046 },
      { protocol = "udp", from = 4045, to = 4046 },
    ]
    smb = [
      { protocol = "tcp", from = 135, to = 135 },
      { protocol = "tcp", from = 139, to = 139 },
      { protocol = "tcp", from = 445, to = 445 },
    ]
    iscsi = [
      { protocol = "tcp", from = 3260, to = 3260 },
    ]
    snapmirror = [
      { protocol = "tcp", from = 11104, to = 11105 },
    ]
  }

  enabled_ports = flatten([
    for set in var.security_group_enabled_protocols : [
      for p in local.ontap_port_sets[set] : {
        key      = "${set}-${p.protocol}-${p.from}"
        protocol = p.protocol
        from     = p.from
        to       = p.to
      }
    ]
  ])

  ingress_rules = local.create_security_group ? merge([
    for ci, cidr in var.security_group_allowed_cidr_blocks : {
      for p in local.enabled_ports : "cidr${ci}-${p.key}" => {
        cidr     = cidr
        protocol = p.protocol
        from     = p.from
        to       = p.to
      }
    }
  ]...) : {}
}

################################################################################
# File system
################################################################################

resource "aws_fsx_ontap_file_system" "this" {
  count = var.create ? 1 : 0

  storage_capacity    = var.storage_capacity
  subnet_ids          = var.subnet_ids
  preferred_subnet_id = coalesce(var.preferred_subnet_id, var.subnet_ids[0])
  deployment_type     = var.deployment_type
  storage_type        = var.storage_type

  throughput_capacity             = var.throughput_capacity_per_ha_pair == null ? var.throughput_capacity : null
  throughput_capacity_per_ha_pair = var.throughput_capacity_per_ha_pair
  ha_pairs                        = var.ha_pairs

  fsx_admin_password        = var.fsx_admin_password
  route_table_ids           = var.route_table_ids
  endpoint_ip_address_range = var.endpoint_ip_address_range
  kms_key_id                = var.kms_key_id
  security_group_ids        = local.security_group_ids

  automatic_backup_retention_days   = var.automatic_backup_retention_days
  daily_automatic_backup_start_time = try(var.automatic_backup_retention_days > 0, false) ? var.daily_automatic_backup_start_time : null
  weekly_maintenance_start_time     = var.weekly_maintenance_start_time

  dynamic "disk_iops_configuration" {
    for_each = var.disk_iops_configuration != null ? [var.disk_iops_configuration] : []

    content {
      mode = disk_iops_configuration.value.mode
      iops = disk_iops_configuration.value.iops
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = var.ha_pairs == null || var.throughput_capacity_per_ha_pair != null
      error_message = "When ha_pairs is set, set throughput_capacity_per_ha_pair as well."
    }

    precondition {
      condition     = var.throughput_capacity_per_ha_pair == null || var.ha_pairs != null
      error_message = "throughput_capacity_per_ha_pair can only be used together with ha_pairs."
    }

    precondition {
      condition     = var.ha_pairs == null || var.ha_pairs == 1 || var.deployment_type == "SINGLE_AZ_2"
      error_message = "More than one HA pair is only supported with deployment_type = \"SINGLE_AZ_2\"."
    }

    precondition {
      condition     = startswith(var.deployment_type, "SINGLE_AZ") ? length(var.subnet_ids) == 1 : length(var.subnet_ids) == 2
      error_message = "Single-AZ deployments take one subnet ID and multi-AZ deployments take two."
    }
  }
}

################################################################################
# Storage virtual machines
################################################################################

resource "aws_fsx_ontap_storage_virtual_machine" "this" {
  for_each = var.create ? var.storage_virtual_machines : {}

  file_system_id             = aws_fsx_ontap_file_system.this[0].id
  name                       = coalesce(each.value.name, each.key)
  root_volume_security_style = each.value.root_volume_security_style
  svm_admin_password         = lookup(var.svm_admin_passwords, each.key, null)

  dynamic "active_directory_configuration" {
    for_each = each.value.active_directory != null ? [each.value.active_directory] : []

    content {
      netbios_name = active_directory_configuration.value.netbios_name

      self_managed_active_directory_configuration {
        domain_name                            = active_directory_configuration.value.domain_name
        username                               = active_directory_configuration.value.username
        password                               = lookup(var.svm_active_directory_passwords, each.key, null)
        dns_ips                                = active_directory_configuration.value.dns_ips
        file_system_administrators_group       = active_directory_configuration.value.file_system_administrators_group
        organizational_unit_distinguished_name = active_directory_configuration.value.organizational_unit_distinguished_name
      }
    }
  }

  tags = merge(var.tags, each.value.tags)
}

################################################################################
# Volumes
################################################################################

resource "aws_fsx_ontap_volume" "this" {
  for_each = var.create ? var.volumes : {}

  name                       = coalesce(each.value.name, each.key)
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.this[each.value.svm_key].id
  size_in_megabytes          = each.value.size_in_megabytes
  junction_path              = each.value.junction_path
  security_style             = each.value.security_style
  ontap_volume_type          = each.value.ontap_volume_type
  volume_style               = each.value.volume_style
  snapshot_policy            = each.value.snapshot_policy
  storage_efficiency_enabled = each.value.storage_efficiency_enabled
  copy_tags_to_backups       = each.value.copy_tags_to_backups
  skip_final_backup          = each.value.skip_final_backup

  dynamic "tiering_policy" {
    for_each = each.value.tiering_policy != null ? [each.value.tiering_policy] : []

    content {
      name           = tiering_policy.value.name
      cooling_period = tiering_policy.value.cooling_period
    }
  }

  tags = merge(var.tags, each.value.tags)
}

################################################################################
# Security group
################################################################################

resource "aws_security_group" "this" {
  count = local.create_security_group ? 1 : 0

  name        = local.security_group_name
  description = var.security_group_description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = local.security_group_name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "cidr" {
  for_each = local.ingress_rules

  security_group_id = aws_security_group.this[0].id
  description       = "ONTAP ${each.value.protocol}/${each.value.from} from ${each.value.cidr}"
  ip_protocol       = each.value.protocol
  from_port         = each.value.from
  to_port           = each.value.to
  cidr_ipv4         = each.value.cidr

  tags = merge(var.tags, { Name = "${local.security_group_name}-${each.key}" })
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  count = local.create_security_group ? 1 : 0

  security_group_id            = aws_security_group.this[0].id
  description                  = "All traffic between members of this security group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.this[0].id

  tags = merge(var.tags, { Name = "${local.security_group_name}-self" })
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  count = local.create_security_group ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  description       = "Allow all outbound IPv4 traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${local.security_group_name}-all-ipv4" })
}
