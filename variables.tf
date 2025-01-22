//SHARED VARIABLES
variable "env" {
  type        = string
  description = "The deployment environment (sandbox, aat, prod etc..)"
}

variable "storage_account_name" {
  description = "(Required) Specifies the name of the storage account. Changing this forces a new resource to be created. This must be unique across the entire Azure service, not just within the resource group."
}

variable "resource_group_name" {
  type        = string
  description = "This is the prefix your resource group name will have for your shared infrastructure"
}

variable "location" {
  description = "(Required) Specifies the supported Azure location where the resource exists. Changing this forces a new resource to be created."
  default     = "uksouth"
}

variable "account_kind" {
  description = "Defines the Kind of account. Valid options are Storage, StorageV2 and BlobStorage. Changing this forces a new resource to be created."
}

variable "account_tier" {
  description = "Defines the Tier to use for this storage account. Valid options are Standard and Premium. Changing this forces a new resource to be created"
  default     = "Standard"
}

variable "account_replication_type" {
  description = "(Required) Defines the type of replication to use for this storage account. Valid options are LRS, GRS, RAGRS and ZRS."
  default     = "LRS"
}

variable "access_tier" {
  description = "(Optional) Defines the access tier for BlobStorage and StorageV2 accounts. Valid options are Hot and Cold, defaults to Hot."
  default     = "Hot"
}

variable "enable_blob_encryption" {
  description = "(Optional) Boolean flag which controls if Encryption Services are enabled for Blob storage, see https://azure.microsoft.com/en-us/documentation/articles/storage-service-encryption/ for more information."
  default     = "true"
}

variable "enable_data_protection" {
  description = "(Optional) Boolean flag which controls if Data Protection are enabled for Blob storage, see https://docs.microsoft.com/en-us/azure/storage/blobs/versioning-overview for more information."
  default     = "false"
}

variable "enable_file_encryption" {
  description = "(Optional) Boolean flag which controls if Encryption Services are enabled for File storage, see https://azure.microsoft.com/en-us/documentation/articles/storage-service-encryption/ for more information."
  default     = "true"
}

variable "enable_https_traffic_only" {
  description = "(Optional) Boolean flag which forces HTTPS if enabled, see https://docs.microsoft.com/en-us/azure/storage/storage-require-secure-transfer/ for more information."
  default     = "true"
}

variable "allow_nested_items_to_be_public" {
  description = "(Optional) Allow or disallow public access to all blobs or containers in the storage account. Defaults to false."
  default     = "false"
}

variable "enable_hns" {
  description = "(Optional) Boolean flag which controls if the hierarchical namespace is enabled for this storage account, required for SFTP support. See https://learn.microsoft.com/en-gb/azure/storage/blobs/data-lake-storage-namespace for more information."
  default     = false
}

variable "enable_sftp" {
  description = "(Optional) Boolean flag which controls if SFTP functionality is enabled for this storage account, Requires `enable_hns` to be `true`. See https://learn.microsoft.com/en-us/azure/storage/blobs/secure-file-transfer-protocol-support for more information."
  default     = false
}

variable "account_encryption_source" {
  description = "(Optional) The Encryption Source for this Storage Account. Possible values are Microsoft.Keyvault and Microsoft.Storage. Defaults to Microsoft.Storage."
  default     = "Microsoft.Storage"
}

variable "ip_rules" {
  type        = list(string)
  description = "(Optional) List of public IP addresses which will have access to storage account."
  default     = []
}

variable "sa_subnets" {
  type        = list(string)
  description = "(Optional) List of subnet ID's which will have access to this storage account."
  default     = []
}

variable "default_action" {
  description = "(Optional) Network rules default action"
  default     = "Deny"
}

variable "managed_identity_object_id" {
  description = "(Optional) Object Id for a Managed Identity to assign roles to, scoped to this storage account."
  default     = ""
}

variable "role_assignments" {
  type        = list(string)
  description = "(Optional) List of roles to assign to the provided Managed Identity, scoped to this storage account."
  default     = []
}

//TAG SPECIFIC VARIABLES
variable "team_name" {
  description = "The name of your team"
  default     = "CNP (Contino)"
}

variable "team_contact" {
  description = "The name of your Slack channel people can use to contact your team about your infrastructure"
  default     = "#Cloud-Native"
}

variable "destroy_me" {
  description = "Here be dragons! In the future if this is set to Yes then automation will delete this resource on a schedule. Please set to No unless you know what you are doing"
  default     = "No"
}

variable "common_tags" {
  type = map(string)
  default = {
    "Team Name" = "pleaseTagMe"
  }
}

//Management Lifecycle
variable "policy" {
  type = list(object({
    name = string
    filters = object({
      prefix_match = list(string)
      blob_types   = list(string)
    })
    actions = object({
      version_delete_after_days_since_creation = number
    })
  }))
  description = "Storage Account Managment Policy"
  default     = []
}

// Containers
variable "containers" {
  type = list(object({
    name        = string
    access_type = string
  }))
  description = "List of Storage Containers"
  default     = []
}

// Tables
variable "tables" {
  type        = list(string)
  description = "List of Storage Tables"
  default     = []
}

// CORS
variable "cors_rules" {
  type = list(object({
    allowed_headers    = list(string)
    allowed_methods    = list(string)
    allowed_origins    = list(string)
    exposed_headers    = list(string)
    max_age_in_seconds = number
  }))
  description = "(Optional) A list of Cors Rule blocks. See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account#cors_rule"
  default     = []
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID to attach private endpoint to - overrides the default subnet id"
  default     = ""
}

variable "private_endpoint_rg_name" {
  description = "Resource group to deploy the private endpoint to - overrides the default resource group name"
  default = ""
}

variable "private_endpoint_subscription_id" {
  description = "Subscription to deploy the private endpoint to - overrides the default subscription id"
  default = ""
}

variable "enable_change_feed" {
  default = "false"
}

variable "immutable_enabled" {
  default = "false"
}

variable "immutability_period" {
  default = "1"
}
