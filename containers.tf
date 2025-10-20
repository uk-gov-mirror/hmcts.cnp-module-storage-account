
resource "azurerm_storage_container" "container" {
  for_each              = { for container in var.containers : container.name => container }
  storage_account_id    = azurerm_storage_account.storage_account.id
  name                  = each.value.name
  container_access_type = each.value.access_type
}
