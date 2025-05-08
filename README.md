# cnp-module-storage-account
Terraservice Module for creating an Azure Resource Manager based storage account.

## Testing
The directories under `test/` provide different testing scenarios.  To use:
* Change to the directory of your choosing and run `terraform init`
* Run `terraform plan, apply`, etc...

## How to use this module

Minimal example:

```terraform
module "this" {
  source                   = "git@github.com:hmcts/cnp-module-storage-account?ref=4.x"
  env                      = var.env
  storage_account_name     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_kind             = var.account_kind
  account_replication_type = var.account_replication_type
}
```

More options:

```terraform
module "this" {
  source                   = "git@github.com:hmcts/cnp-module-storage-account?ref=4.x"
  env                      = var.env
  storage_account_name     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_kind             = var.account_kind
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  access_tier              = var.access_tier

  ip_rules = var.ip_rules

  sa_subnets = var.sa_subnets
  
  managed_identity_object_id = var.managed_identity_object_id
  role_assignments = [
    "Storage Blob Data Contributor"
  ]
}
```

## Important note about network access 

This module can automatically prevent access to Storage Account data plane from public internet.

You need to explicitly provide either list of public IP's or Azure subnets ID's to allow access.

Two variables responsible for those settings are: `ip_rules` and `sa_subnets`

Example:

```
  ip_rules = [
    "86.14.143.106",
    "213.121.161.124",
  ]
```

```
  sa_subnets = [
    "/subscriptions/<some_subscription_id>/resourcegroups/<some_rg>/providers/microsoft.network/virtualnetworks/<some_vnet>/subnets/test-subnet1",
    "/subscriptions/<some_subscription_id>/resourcegroups/<some_rg>/providers/microsoft.network/virtualnetworks/<some_vnet>/subnets/test-subnet2"
  ]
```

Alternatively enable private endpoints:

```terraform
locals {
  private_endpoint_rg_name   = var.businessArea == "sds" ? "ss-${var.env}-network-rg" : "${var.businessArea}-${var.env}-network-rg"
  private_endpoint_vnet_name = var.businessArea == "sds" ? "ss-${var.env}-vnet" : "${var.businessArea}-${var.env}-vnet"
}

# CFT only, on SDS remove this provider
provider "azurerm" {
  alias           = "private_endpoints"
  subscription_id = var.aks_subscription_id
  features {}
  skip_provider_registration = true
}

data "azurerm_subnet" "private_endpoints" {
  # CFT only you will need to provide an extra provider, uncomment the below line, on SDS remove this line and the next
  # provider = azurerm.private_endpoints

  resource_group_name  = local.private_endpoint_rg_name
  virtual_network_name = local.private_endpoint_vnet_name
  name                 = "private-endpoints"
}

module "this" {
  source                        = "git@github.com:hmcts/cnp-module-storage-account?ref=4.x"
  env                           = var.env
  storage_account_name          = var.storage_account_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_kind                  = var.account_kind
  account_replication_type      = var.account_replication_type
  public_network_access_enabled = false

  private_endpoint_subnet_id = data.azurerm_subnet.private_endpoints.id
}
```

variables.tf:

```terraform
variable "businessArea" {
  default = "" # sds or cft, fill this in
}

variable "aks_subscription_id" {} # supplied by the Jenkins library and only needed on CFT
```

## Using this module with new subnet

This module was created with assumption that all required subnets are already present in Azure prior to running it.

In special cases when as part of running this module you are also creating new subnet which should be added to subnet rules inside storage account please ensure to use `depends_on` section. 
This way module will wait for subnet to get created first before attempting to reference it.

For examples you can refer to files inside test folder of this repository.

Example: 

```
depends_on = ["${azurerm_subnet.subnet1.id}","${azurerm_subnet.subnet2.id}"]
```

## Assigning roles to a Managed Identity
In order to grant access to the Storage Account to a specific Managed Identity, you can provide the Object Id for 
MI along with a list of [roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage) 
to assign to it. There is a variable called `allowed_roles` in [main.tf](./main.tf) which is whitelist of roles which 
can be used. A PR will be needed if different roles are required.

## Management Policy
Management Policy creates a lifecycle policy for the storage account.
Currently there is only version deletion policy coded in, but it can be expanded to consider more actions.

[Terraform Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_management_policy)

### Example Usage
```
sa_policy = [
    {
      name = "BlobRetentionPolicy"
      filters = {
        prefix_match = ["container1/prefix1"]
        blob_types   = ["blockBlob"]
      }
      actions = {
        version_delete_after_days_since_creation = 180
      }
    }
  ]
```

## Enabling SFTP Connectivity

SFTP connectivity for Azure storage acount is only supported on certain SKUs. 

Ensure:
- `account_kind` is set to either `StorageV2` or `BlockBlobStorage`.
- Hierarchical namespace (HNS) is enabled on the storage account by setting `enable_hns` to `true`. 
- `enable_sftp` is set to true

```terraform
module "sftp_storage" {
  source                   = "git@github.com:hmcts/cnp-module-storage-account?ref=4.x"
  
  ...
  
  account_kind             = "StorageV2"
  enable_hns               = true
  enable_sftp              = true
}
```

[Azure Documentation on Storage Account SFTP](https://learn.microsoft.com/en-us/azure/storage/blobs/secure-file-transfer-protocol-support-how-to?tabs=azure-portal)

### Creating Local Users

To actually connect via SFTP, you will require a local user for the storage account, as well as an SSH keypair. `azurerm_storage_account_local_user` has been added to facilitate management of local users via terraform.

[Terraform Documentation on Storage Account Local Users](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_local_user)

## Privileged identity management

Privileged identity management (PIM) can we used in limited cases where people need access to the storage account.
For access to production data they should be assigned to a group that only contains members with Security Clearance (SC).
Create a new group for it in [hmcts/devops-azure-ad](https://github.com/hmcts/devops-azure-ad/blob/master/users/groups.yml).

Example configuration:

```terraform
data "azuread_group" "sc_group" {
  display_name     = "DTS my team SC"
  security_enabled = true
}

module "this" {
  source    = "git@github.com:hmcts/cnp-module-storage-account?ref=4.x"
  env       = var.env
  ...

  # only enabled on prod
  pim_roles = var.env != prod ? {} : {
    "Storage Blob Delegator" = {
      principal_id = data.sc_group.object_id
    }

    "Storage Blob Data Reader" = {
      principal_id = data.sc_group.object_id
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->


## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | n/a |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Resources

| Name | Type |
|------|------|
| [azapi_update_resource.defender_settings](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/update_resource) | resource |
| [azurerm_pim_eligible_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/pim_eligible_role_assignment) | resource |
| [azurerm_private_endpoint.dfs_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_private_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_role_assignment.storage-account-role-assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.container](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_management_policy.storage-account-policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_management_policy) | resource |
| [azurerm_storage_table.tables](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_table) | resource |
| [random_string.storage_account_random_string](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_rotating.rotate](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [time_static.pim_expiry](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [time_static.pim_start](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [azurerm_role_definition.role_name](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/role_definition) | data source |
| [azurerm_subscription.primary](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_tier"></a> [access\_tier](#input\_access\_tier) | (Optional) Defines the access tier for BlobStorage and StorageV2 accounts. Valid options are Hot and Cold, defaults to Hot. | `string` | `"Hot"` | no |
| <a name="input_account_encryption_source"></a> [account\_encryption\_source](#input\_account\_encryption\_source) | (Optional) The Encryption Source for this Storage Account. Possible values are Microsoft.Keyvault and Microsoft.Storage. Defaults to Microsoft.Storage. | `string` | `"Microsoft.Storage"` | no |
| <a name="input_account_kind"></a> [account\_kind](#input\_account\_kind) | Defines the Kind of account. Valid options are Storage, StorageV2 and BlobStorage. Changing this forces a new resource to be created. | `any` | n/a | yes |
| <a name="input_account_replication_type"></a> [account\_replication\_type](#input\_account\_replication\_type) | (Required) Defines the type of replication to use for this storage account. Valid options are LRS, GRS, RAGRS and ZRS. | `string` | `"LRS"` | no |
| <a name="input_account_tier"></a> [account\_tier](#input\_account\_tier) | Defines the Tier to use for this storage account. Valid options are Standard and Premium. Changing this forces a new resource to be created | `string` | `"Standard"` | no |
| <a name="input_allow_nested_items_to_be_public"></a> [allow\_nested\_items\_to\_be\_public](#input\_allow\_nested\_items\_to\_be\_public) | (Optional) Allow or disallow public access to all blobs or containers in the storage account. Defaults to false. | `string` | `"false"` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | TAG SPECIFIC VARIABLES | `map(string)` | n/a | yes |
| <a name="input_containers"></a> [containers](#input\_containers) | List of Storage Containers | <pre>list(object({<br/>    name        = string<br/>    access_type = string<br/>  }))</pre> | `[]` | no |
| <a name="input_cors_rules"></a> [cors\_rules](#input\_cors\_rules) | (Optional) A list of Cors Rule blocks. See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account#cors_rule | <pre>list(object({<br/>    allowed_headers    = list(string)<br/>    allowed_methods    = list(string)<br/>    allowed_origins    = list(string)<br/>    exposed_headers    = list(string)<br/>    max_age_in_seconds = number<br/>  }))</pre> | `[]` | no |
| <a name="input_create_dfs_private_endpoint"></a> [create\_dfs\_private\_endpoint](#input\_create\_dfs\_private\_endpoint) | Boolean flag to enable or disable DFS private endpoint | `bool` | `false` | no |
| <a name="input_cross_tenant_replication_enabled"></a> [cross\_tenant\_replication\_enabled](#input\_cross\_tenant\_replication\_enabled) | (Optional) Should cross Tenant replication be enabled | `bool` | `false` | no |
| <a name="input_default_action"></a> [default\_action](#input\_default\_action) | (Optional) Network rules default action | `string` | `"Deny"` | no |
| <a name="input_defender_enabled"></a> [defender\_enabled](#input\_defender\_enabled) | Enable Defender for Cloud, it costs $10per month / storage account and $0.15/GB scanned for On-Upload Malware Scanning, enable with caution | `bool` | `false` | no |
| <a name="input_defender_malware_scanning_cap_gb_per_month"></a> [defender\_malware\_scanning\_cap\_gb\_per\_month](#input\_defender\_malware\_scanning\_cap\_gb\_per\_month) | Maximum amount of data scanned per month in GB, it costs $0.15/GB scanned | `number` | `5000` | no |
| <a name="input_defender_malware_scanning_enabled"></a> [defender\_malware\_scanning\_enabled](#input\_defender\_malware\_scanning\_enabled) | Enables On-Upload Malware Scanning | `bool` | `true` | no |
| <a name="input_defender_override_subscription_level_settings"></a> [defender\_override\_subscription\_level\_settings](#input\_defender\_override\_subscription\_level\_settings) | Whether to override subscription level settings | `bool` | `true` | no |
| <a name="input_defender_sensitive_data_discovery_enabled"></a> [defender\_sensitive\_data\_discovery\_enabled](#input\_defender\_sensitive\_data\_discovery\_enabled) | Enables Sensitive Data Discovery | `bool` | `true` | no |
| <a name="input_destroy_me"></a> [destroy\_me](#input\_destroy\_me) | Unused, do not add to your configuration | `any` | `null` | no |
| <a name="input_enable_blob_encryption"></a> [enable\_blob\_encryption](#input\_enable\_blob\_encryption) | (Optional) Boolean flag which controls if Encryption Services are enabled for Blob storage, see https://azure.microsoft.com/en-us/documentation/articles/storage-service-encryption/ for more information. | `string` | `"true"` | no |
| <a name="input_enable_change_feed"></a> [enable\_change\_feed](#input\_enable\_change\_feed) | n/a | `string` | `"false"` | no |
| <a name="input_enable_data_protection"></a> [enable\_data\_protection](#input\_enable\_data\_protection) | (Optional) Boolean flag which controls if Data Protection are enabled for Blob storage, see https://docs.microsoft.com/en-us/azure/storage/blobs/versioning-overview for more information. | `string` | `"false"` | no |
| <a name="input_enable_file_encryption"></a> [enable\_file\_encryption](#input\_enable\_file\_encryption) | (Optional) Boolean flag which controls if Encryption Services are enabled for File storage, see https://azure.microsoft.com/en-us/documentation/articles/storage-service-encryption/ for more information. | `string` | `"true"` | no |
| <a name="input_enable_hns"></a> [enable\_hns](#input\_enable\_hns) | (Optional) Boolean flag which controls if the hierarchical namespace is enabled for this storage account, required for SFTP support. See https://learn.microsoft.com/en-gb/azure/storage/blobs/data-lake-storage-namespace for more information. | `bool` | `false` | no |
| <a name="input_enable_https_traffic_only"></a> [enable\_https\_traffic\_only](#input\_enable\_https\_traffic\_only) | (Optional) Boolean flag which forces HTTPS if enabled, see https://docs.microsoft.com/en-us/azure/storage/storage-require-secure-transfer/ for more information. | `string` | `"true"` | no |
| <a name="input_enable_nfs"></a> [enable\_nfs](#input\_enable\_nfs) | (Optional) Boolean flag which controls if NFS is enabled for this storage account, Requires `enable_nfs` to be `true`. | `bool` | `false` | no |
| <a name="input_enable_sftp"></a> [enable\_sftp](#input\_enable\_sftp) | (Optional) Boolean flag which controls if SFTP functionality is enabled for this storage account, Requires `enable_hns` to be `true`. See https://learn.microsoft.com/en-us/azure/storage/blobs/secure-file-transfer-protocol-support for more information. | `bool` | `false` | no |
| <a name="input_enable_versioning"></a> [enable\_versioning](#input\_enable\_versioning) | Whether to enable versioning when data protection has been enabled. Defaults to true. | `bool` | `true` | no |
| <a name="input_env"></a> [env](#input\_env) | The deployment environment (sandbox, aat, prod etc..) | `string` | n/a | yes |
| <a name="input_immutability_period"></a> [immutability\_period](#input\_immutability\_period) | n/a | `string` | `"1"` | no |
| <a name="input_immutable_enabled"></a> [immutable\_enabled](#input\_immutable\_enabled) | n/a | `string` | `"false"` | no |
| <a name="input_ip_rules"></a> [ip\_rules](#input\_ip\_rules) | (Optional) List of public IP addresses which will have access to storage account. | `list(string)` | `[]` | no |
| <a name="input_location"></a> [location](#input\_location) | (Required) Specifies the supported Azure location where the resource exists. Changing this forces a new resource to be created. | `string` | `"uksouth"` | no |
| <a name="input_managed_identity_object_id"></a> [managed\_identity\_object\_id](#input\_managed\_identity\_object\_id) | (Optional) Object Id for a Managed Identity to assign roles to, scoped to this storage account. | `string` | `""` | no |
| <a name="input_pim_roles"></a> [pim\_roles](#input\_pim\_roles) | { 'Role name' = { principal\_id = 'principal\_id' } }, only certain roles are supported | <pre>map(object({<br/>    principal_id = string<br/>  }))</pre> | `{}` | no |
| <a name="input_policy"></a> [policy](#input\_policy) | Storage Account Managment Policy | <pre>list(object({<br/>    name = string<br/>    filters = object({<br/>      prefix_match = list(string)<br/>      blob_types   = list(string)<br/>    })<br/>    actions = object({<br/>      version_delete_after_days_since_creation = number<br/>    })<br/>  }))</pre> | `[]` | no |
| <a name="input_private_endpoint_subnet_id"></a> [private\_endpoint\_subnet\_id](#input\_private\_endpoint\_subnet\_id) | Subnet ID to attach private endpoint to - overrides the default subnet id | `string` | `""` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | (Optional) Defaults to null. Setting this to false will block public access to the storage account. See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account#public_network_access_enabled | `bool` | `null` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | This is the prefix your resource group name will have for your shared infrastructure | `string` | n/a | yes |
| <a name="input_restore_policy_days"></a> [restore\_policy\_days](#input\_restore\_policy\_days) | n/a | `any` | `null` | no |
| <a name="input_retention_period"></a> [retention\_period](#input\_retention\_period) | (Optional) Specifies the number of days that the blob should be retained, between 1 and 365 days. Defaults to 365 | `number` | `365` | no |
| <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments) | (Optional) List of roles to assign to the provided Managed Identity, scoped to this storage account. | `list(string)` | `[]` | no |
| <a name="input_sa_subnets"></a> [sa\_subnets](#input\_sa\_subnets) | (Optional) List of subnet ID's which will have access to this storage account. | `list(string)` | `[]` | no |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | (Required) Specifies the name of the storage account. Changing this forces a new resource to be created. This must be unique across the entire Azure service, not just within the resource group. | `any` | n/a | yes |
| <a name="input_tables"></a> [tables](#input\_tables) | List of Storage Tables | `list(string)` | `[]` | no |
| <a name="input_team_contact"></a> [team\_contact](#input\_team\_contact) | Unused, do not add to your configuration | `any` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_storageaccount_id"></a> [storageaccount\_id](#output\_storageaccount\_id) | The storage account Resource ID. |
| <a name="output_storageaccount_name"></a> [storageaccount\_name](#output\_storageaccount\_name) | The storage account name. |
| <a name="output_storageaccount_primary_access_key"></a> [storageaccount\_primary\_access\_key](#output\_storageaccount\_primary\_access\_key) | The primary access key for the storage account. |
| <a name="output_storageaccount_primary_blob_connection_string"></a> [storageaccount\_primary\_blob\_connection\_string](#output\_storageaccount\_primary\_blob\_connection\_string) | The connection string associated with the primary blob location. |
| <a name="output_storageaccount_primary_blob_endpoint"></a> [storageaccount\_primary\_blob\_endpoint](#output\_storageaccount\_primary\_blob\_endpoint) | The endpoint URL for blob storage in the primary location. |
| <a name="output_storageaccount_primary_connection_string"></a> [storageaccount\_primary\_connection\_string](#output\_storageaccount\_primary\_connection\_string) | The connection string associated with the primary location. |
| <a name="output_storageaccount_primary_dfs_endpoint"></a> [storageaccount\_primary\_dfs\_endpoint](#output\_storageaccount\_primary\_dfs\_endpoint) | The endpoint URL for DFS in the primary location. |
| <a name="output_storageaccount_primary_file_endpoint"></a> [storageaccount\_primary\_file\_endpoint](#output\_storageaccount\_primary\_file\_endpoint) | The endpoint URL for file storage in the primary location. |
| <a name="output_storageaccount_primary_location"></a> [storageaccount\_primary\_location](#output\_storageaccount\_primary\_location) | The primary location of the storage account. |
| <a name="output_storageaccount_primary_queue_endpoint"></a> [storageaccount\_primary\_queue\_endpoint](#output\_storageaccount\_primary\_queue\_endpoint) | The endpoint URL for queue storage in the primary location. |
| <a name="output_storageaccount_primary_table_endpoint"></a> [storageaccount\_primary\_table\_endpoint](#output\_storageaccount\_primary\_table\_endpoint) | The endpoint URL for table storage in the primary location. |
| <a name="output_storageaccount_secondary_access_key"></a> [storageaccount\_secondary\_access\_key](#output\_storageaccount\_secondary\_access\_key) | The secondary access key for the storage account. |
| <a name="output_storageaccount_secondary_connection_string"></a> [storageaccount\_secondary\_connection\_string](#output\_storageaccount\_secondary\_connection\_string) | The connection string associated with the secondary location. |
| <a name="output_storageaccount_secondary_location"></a> [storageaccount\_secondary\_location](#output\_storageaccount\_secondary\_location) | The secondary location of the storage account. |
<!-- END_TF_DOCS -->
