provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Use Azure AD authentication for storage operations
  storage_use_azuread = true
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# Kubernetes and Helm providers are only configured if AKS is enabled
# If AKS is disabled, these providers will not be initialized
# To use these providers, ensure enable_aks = true

