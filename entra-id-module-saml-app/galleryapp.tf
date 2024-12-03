data "azuread_application_template" "gallerytemplate" {
  display_name = local.gallery_app_name
}

resource "azuread_application_from_template" "saml_app_template" {
  display_name = var.app_config.DisplayName
  template_id  = data.azuread_application_template.gallerytemplate.template_id
}

data "azuread_application" "saml_app_data" {
  object_id = azuread_application_from_template.saml_app_template.application_object_id
}

data "azuread_service_principal" "saml_sp_data" {
  object_id = azuread_application_from_template.saml_app_template.service_principal_object_id
}