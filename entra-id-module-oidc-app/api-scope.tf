# Create random UUIDs for each scope only if Scopes exist and are not empty
resource "random_uuid" "random_scope_id" {
  for_each = length(lookup(var.app_config, "Scopes", [])) > 0 ? {
    for idx, scope in lookup(var.app_config, "Scopes", []) : idx => scope
  } : {}

}

# Create permission scopes only if Scopes exist and are not empty
resource "azuread_application_permission_scope" "permission_scope" {
  for_each = length(lookup(var.app_config, "Scopes", [])) > 0 ? {
    for idx, scope in lookup(var.app_config, "Scopes", []) : idx => scope
  } : {}

  application_id = azuread_application_registration.oidc_app.id
  scope_id       = random_uuid.random_scope_id[each.key].id
  value          = each.value.scope_name
  type           = each.value.type
  admin_consent_description  = each.value.admin_consent_description
  admin_consent_display_name = each.value.admin_consent_display_name
  user_consent_description   = each.value.user_consent_description
  user_consent_display_name  = each.value.user_consent_display_name
}

resource "azuread_application_identifier_uri" "identifier_uri" {
  count = length(lookup(var.app_config, "identifier_uri", "")) > 0 ? 1 : 0
  application_id = azuread_application_registration.oidc_app.id
  identifier_uri = var.app_config.identifier_uri
}