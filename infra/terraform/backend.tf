terraform {
  backend "azurerm" {
    resource_group_name  = "rg-isaru66-aks-terraform-aiapp"
    storage_account_name = "stisaru66aksaiapp"
    container_name       = "tfstate"
    key                  = "aks-ai-app.tfstate"
    use_azuread_auth     = true # Use Azure AD authentication instead of access keys
    # Workspace name is automatically appended to the state file path
    # Example: env:/dev/aks-ai-app.tfstate, env:/production/aks-ai-app.tfstate
  }
}
