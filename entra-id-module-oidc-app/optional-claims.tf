
resource "azuread_application_optional_claims" "optional_claims" {
  count = try(var.app_config.optional_claims != null, false) ? 1 : 0

  application_id = azuread_application_registration.oidc_app.id

  dynamic "access_token" {
    for_each = try(var.app_config.optional_claims.access_tokens, [])
    content {
      name                  = access_token.value.name
      essential             = try(access_token.value.essential, null)
      additional_properties = try(access_token.value.additional_properties, null)
      source                = try(access_token.value.source, null)
    }
  }

  dynamic "id_token" {
    for_each = try(var.app_config.optional_claims.id_tokens, [])
    content {
      name                  = id_token.value.name
      essential             = try(id_token.value.essential, null)
      additional_properties = try(id_token.value.additional_properties, null)
      source                = try(id_token.value.source, null)
    }
  }

  dynamic "saml2_token" {
    for_each = try(var.app_config.optional_claims.saml2_tokens, [])
    content {
      name                  = saml2_token.value.name
      essential             = try(saml2_token.value.essential, null)
      additional_properties = try(saml2_token.value.additional_properties, null)
      source                = try(saml2_token.value.source, null)
    }
  }
}