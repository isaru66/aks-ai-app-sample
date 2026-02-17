data "azuread_client_config" "current" {}

# Azure AD Application
resource "azuread_application" "app" {
  display_name = "sp-aiapp-${var.resource_suffix}-${var.environment}"
  owners       = [data.azuread_client_config.current.object_id]

  tags = [
    "Environment:${var.environment}",
    "ManagedBy:Terraform",
    "Purpose:AIApp"
  ]
}

# Service Principal
resource "azuread_service_principal" "sp" {
  client_id = azuread_application.app.client_id
  owners    = [data.azuread_client_config.current.object_id]

  tags = [
    "Environment:${var.environment}",
    "ManagedBy:Terraform",
    "Purpose:AIApp"
  ]
}

# Client Secret
resource "time_rotating" "secret_rotation" {
  rotation_years = var.client_secret_expiration_years
}

resource "azuread_application_password" "client_secret" {
  application_id = azuread_application.app.id
  display_name   = "terraform-managed-secret"
  
  rotate_when_changed = {
    rotation = time_rotating.secret_rotation.id
  }
}

# Role Assignment: Cognitive Services OpenAI User
resource "azurerm_role_assignment" "openai_user" {
  scope                = var.ai_services_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azuread_service_principal.sp.object_id
}

# Role Assignment: Cognitive Services User
resource "azurerm_role_assignment" "cognitive_user" {
  scope                = var.ai_services_id
  role_definition_name = "Cognitive Services User"
  principal_id         = azuread_service_principal.sp.object_id
}

# Role Assignment: Storage Blob Data Contributor (optional)
resource "azurerm_role_assignment" "storage_contributor" {
  count                = var.assign_storage_role && var.storage_account_id != null ? 1 : 0
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.sp.object_id
}

# Role Assignment: Key Vault Secrets User (optional)
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  count                = var.assign_keyvault_role && var.key_vault_id != null ? 1 : 0
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.sp.object_id
}
