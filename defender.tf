resource "azapi_update_resource" "defender_settings" {
  name      = "current"
  type      = "Microsoft.Security/DefenderForStorageSettings@2022-12-01-preview"
  parent_id = azurerm_storage_account.storage_account.id

  body = {
    properties = {
      isEnabled = var.defender_enabled

      malwareScanning = {
        onUpload = {
          isEnabled     = var.defender_enabled == false ? false : var.defender_malware_scanning_enabled
          capGBPerMonth = var.defender_enabled == false ? -1 : var.defender_malware_scanning_cap_gb_per_month
        }
      }

      sensitiveDataDiscovery = {
        isEnabled = var.defender_enabled == false ? false : var.defender_sensitive_data_discovery_enabled
      }

      overrideSubscriptionLevelSettings = var.defender_override_subscription_level_settings
    }
  }
}
