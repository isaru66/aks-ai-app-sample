# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = replace("st${var.resource_suffix}", "-", "")
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  # Security settings
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # Use Azure AD authentication

  # Advanced features - HNS disabled (required for AI Foundry compatibility)
  is_hns_enabled = false

  # Network rules
  public_network_access_enabled = !var.enable_private_endpoint

  network_rules {
    default_action = var.enable_private_endpoint ? "Deny" : "Allow"
    bypass         = ["AzureServices"]
    ip_rules       = []
  }

  # Blob properties
  blob_properties {
    # Enable versioning (production only)
    versioning_enabled = var.environment == "production" ? true : false

    # Enable soft delete for blobs
    delete_retention_policy {
      days = 7
    }

    # Enable soft delete for containers
    container_delete_retention_policy {
      days = 7
    }

    # CORS rules (for frontend direct upload if needed)
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "POST", "PUT"]
      allowed_origins    = ["*"] # Restrict in production
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  tags = var.tags

  # Ignore queue_properties block to avoid authentication issues
  lifecycle {
    ignore_changes = [
      queue_properties
    ]
  }
}

# Get current client (user/service principal running Terraform)
data "azurerm_client_config" "current" {}

# Role assignment: Storage Blob Data Contributor for Terraform user
resource "azurerm_role_assignment" "terraform_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role assignment: Storage Queue Data Contributor for Terraform user
resource "azurerm_role_assignment" "terraform_queue_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Role assignment: Storage Account Contributor for Terraform user
resource "azurerm_role_assignment" "terraform_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Blob container for documents
resource "azurerm_storage_container" "documents" {
  name                 = "documents"
  storage_account_id   = azurerm_storage_account.main.id
  container_access_type = "private"

  depends_on = [
    azurerm_role_assignment.terraform_blob_contributor
  ]
}

# Blob container for backups
resource "azurerm_storage_container" "backups" {
  name                 = "backups"
  storage_account_id   = azurerm_storage_account.main.id
  container_access_type = "private"

  depends_on = [
    azurerm_role_assignment.terraform_blob_contributor
  ]
}

# Queue for async processing
resource "azurerm_storage_queue" "processing" {
  name               = "document-processing"
  storage_account_id = azurerm_storage_account.main.id

  depends_on = [
    azurerm_role_assignment.terraform_queue_contributor
  ]
}

# Private endpoint for Blob (if enabled)
resource "azurerm_private_endpoint" "blob" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "pe-st-blob-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-st-blob-${var.resource_suffix}"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  tags = var.tags
}

# Private endpoint for Queue (if enabled)
resource "azurerm_private_endpoint" "queue" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "pe-st-queue-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-st-queue-${var.resource_suffix}"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["queue"]
  }

  tags = var.tags
}

# Management policy for lifecycle
resource "azurerm_storage_management_policy" "main" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "deleteOldBackups"
    enabled = true

    filters {
      prefix_match = ["backups/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 90
      }
    }
  }

  rule {
    name    = "archiveOldDocuments"
    enabled = var.environment == "production"

    filters {
      prefix_match = ["documents/archive/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
      }
    }
  }
}
