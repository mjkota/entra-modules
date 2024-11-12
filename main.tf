resource "azuread_service_principal" "saml_sp" {
  client_id = data.azuread_application.saml_app_data.client_id
  use_existing                 = true
  app_role_assignment_required = try(var.app_config.GeneralServicePrincipalConfiguration.appRoleAssignment, true)
  account_enabled              = try(var.app_config.GeneralServicePrincipalConfiguration.accountEnabled, true)
  preferred_single_sign_on_mode = try(var.app_config.GeneralServicePrincipalConfiguration.preferredSsoMode, "saml")
  notification_email_addresses = try(var.app_config.BasicSamlServicePrincipalConfiguration.notificationEmailAddresses, [""])
  login_url                    = try(var.app_config.BasicSamlServicePrincipalConfiguration.loginUrl, null)
  owners                       = [data.azuread_client_config.current.object_id]

  saml_single_sign_on {
    relay_state = try(var.app_config.BasicSamlServicePrincipalConfiguration.relayState, null)
  }

  feature_tags {
    hide = try(var.app_config.GeneralServicePrincipalConfiguration.featureTags.hide, true)
    enterprise = true
   # custom_single_sign_on = local.custom_single_sign_on_value
  }
}

resource "time_rotating" "saml-certificate" {
  rotation_years = try(var.app_config.TokenSigningCertExpiryAge, 3)
}

resource "azuread_service_principal_token_signing_certificate" "saml_cert" {
  service_principal_id = azuread_service_principal.saml_sp.id
  display_name         = "CN=${var.app_config.DisplayName} token-sign"
  end_date             = time_rotating.saml-certificate.rotation_rfc3339
}

resource "azuread_claims_mapping_policy" "claims_policy" {
  count = try(length(var.app_config.ClaimsMapping.ClaimsMappingPolicy), 0) > 0 ? 1 : 0
  definition = [
    jsonencode({
      ClaimsMappingPolicy = var.app_config.ClaimsMapping.ClaimsMappingPolicy
    })
  ]
  display_name = "${var.app_config.DisplayName} Claims Policy"
}

resource "azuread_service_principal_claims_mapping_policy_assignment" "claims_assignment" {
  count = try(length(var.app_config.ClaimsMapping.ClaimsMappingPolicy), 0) > 0 ? 1 : 0
  claims_mapping_policy_id = azuread_claims_mapping_policy.claims_policy[0].id
  service_principal_id     = azuread_service_principal.saml_sp.id
}


resource "null_resource" "run_powershell_script" {
  triggers = {
  #  Trigger based on changes to replyUrls and custom security attributes
    replyurl = try(join(",", [for url in var.app_config.BasicSamlServicePrincipalConfiguration.replyUrls :"${url.Uri}-${url.Index}"]), "")
    custom_security_attributes = jsonencode(var.app_config.CustomSecurityAttributes)
    default_url =  try(var.app_config.BasicSamlServicePrincipalConfiguration.defaultReplyUrl, "")
  }

  provisioner "local-exec" {
  # Execute the PowerShell script and pass the JSON file name
    command = <<EOT
      pwsh -Command "& { .terraform/modules/entra-id-module-saml-app/update-app.ps1 -jsonFile saml-app/applications/${var.env}/${var.app_space}/${var.json_file} };exit \$LASTEXITCODE"
    EOT
  }
  depends_on = [data.azuread_application.saml_app_data,azuread_service_principal.saml_sp]
}


