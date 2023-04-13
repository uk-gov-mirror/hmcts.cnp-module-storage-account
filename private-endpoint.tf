provider "azurerm" {
  count = var.private_endpoint_subscription_id != "" ? 1 : 0

  alias = "private_endpoints"
  subscription_id = var.private_endpoint_subscription_id
  features {}
  skip_provider_registration = true
}

# TODO make a breaking change at some point to automatically default a subnet id like in:
# https://github.com/hmcts/terraform-module-servicebus-namespace/blob/1b9bd99b936710ab63aeb89c167266f2ad0b09ba/private-endpoint.tf#L1-L15
resource "azurerm_private_endpoint" "this" {
  count = var.private_endpoint_subnet_id != "" ? 1 : 0

  // This should leave unspecified?
  provider = var.private_endpoint_subscription_id != "" ? azurerm.private_endpoints[0] : null

  name                = local.storage_account_name
  resource_group_name = var.private_endpoint_rg_name != "" ? var.private_endpoint_rg_name : var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = local.storage_account_name
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.storage_account.id
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "endpoint-dnszonegroup"
    private_dns_zone_ids = ["/subscriptions/1baf5470-1c3e-40d3-a6f7-74bfbce4b348/resourceGroups/core-infra-intsvc-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"]
  }

  tags = var.common_tags
}
