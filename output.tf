output "application_id" {
  description = "The ID of the created Azure AD application."
  value       =  data.azuread_application.saml_app_data.client_id
}

output "service_principal_id" {
  description = "The ID of the created Azure AD service principal."
  value       = azuread_service_principal.saml_sp.id
}