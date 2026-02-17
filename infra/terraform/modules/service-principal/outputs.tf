output "client_id" {
  description = "Service Principal Client ID (Application ID)"
  value       = azuread_application.app.client_id
}

output "client_secret" {
  description = "Service Principal Client Secret"
  value       = azuread_application_password.client_secret.value
  sensitive   = true
}

output "tenant_id" {
  description = "Azure AD Tenant ID"
  value       = data.azuread_client_config.current.tenant_id
}

output "object_id" {
  description = "Service Principal Object ID"
  value       = azuread_service_principal.sp.object_id
}

output "display_name" {
  description = "Service Principal Display Name"
  value       = azuread_application.app.display_name
}

output "application_id" {
  description = "Azure AD Application ID"
  value       = azuread_application.app.id
}
