resource "random_string" "storage_account_random_string" {
  length  = 24
  special = false
  upper   = false
}

locals {
  default_storage_account_name = random_string.storage_account_random_string.result
  storage_account_name         = var.storage_account_name != "" ? var.storage_account_name : local.default_storage_account_name

  allowed_roles = [
    "Storage Blob Delegator",
    "Storage Blob Data Contributor",
    "Storage Blob Data Reader",
    "Azure Storage Account Blob Tagging"
  ]

  role_assignments = [
    for role in var.role_assignments : role if contains(local.allowed_roles, role)
  ]
}

resource "azurerm_storage_account" "storage_account" {
  name                             = local.storage_account_name
  resource_group_name              = var.resource_group_name
  location                         = var.location
  account_kind                     = var.account_kind
  account_tier                     = var.account_tier
  account_replication_type         = var.account_replication_type
  access_tier                      = var.access_tier
  https_traffic_only_enabled       = var.enable_https_traffic_only
  min_tls_version                  = "TLS1_2"
  allow_nested_items_to_be_public  = var.allow_nested_items_to_be_public
  sftp_enabled                     = var.enable_sftp
  is_hns_enabled                   = var.enable_hns
  nfsv3_enabled                    = var.enable_nfs
  public_network_access_enabled    = var.public_network_access_enabled
  cross_tenant_replication_enabled = var.cross_tenant_replication_enabled

  dynamic "immutability_policy" {
    for_each = var.immutable_enabled == true ? [1] : []
    content {
      allow_protected_append_writes = true
      state                         = "Unlocked"
      period_since_creation_in_days = var.immutability_period
    }
  }
  dynamic "blob_properties" {
    for_each = var.enable_data_protection == true ? [1] : []
    content {
      versioning_enabled  = var.enable_versioning
      change_feed_enabled = var.enable_change_feed

      container_delete_retention_policy {
        days = 7
      }
      delete_retention_policy {
        days = var.retention_period
      }
      dynamic "restore_policy" {
        for_each = var.restore_policy_days != null ? [1] : []
        content {
          days = var.restore_policy_days
        }
      }
      dynamic "cors_rule" {
        for_each = var.cors_rules

        content {
          allowed_headers    = cors_rule.value["allowed_headers"]
          allowed_methods    = cors_rule.value["allowed_methods"]
          allowed_origins    = cors_rule.value["allowed_origins"]
          exposed_headers    = cors_rule.value["exposed_headers"]
          max_age_in_seconds = cors_rule.value["max_age_in_seconds"]
        }
      }
    }
  }

  network_rules {
    bypass                     = ["AzureServices"]
    ip_rules                   = var.ip_rules
    virtual_network_subnet_ids = var.sa_subnets
    default_action             = var.default_action
  }

  tags = var.common_tags
}

resource "azurerm_storage_management_policy" "storage-account-policy" {
  count              = length(var.policy) > 0 ? 1 : 0
  storage_account_id = azurerm_storage_account.storage_account.id

  dynamic "rule" {
    for_each = var.policy
    content {
      name    = rule.value.name
      enabled = true
      filters {
        prefix_match = rule.value.filters.prefix_match
        blob_types   = rule.value.filters.blob_types
      }
      actions {
        version {
          delete_after_days_since_creation = rule.value.actions.version_delete_after_days_since_creation
        }
      }
    }
  }
}

resource "azurerm_role_assignment" "storage-account-role-assignment" {
  for_each             = toset(local.role_assignments)
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = each.value
  principal_id         = var.managed_identity_object_id
}
