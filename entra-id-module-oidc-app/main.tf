locals {
  CreateClientSecret = try(var.app_config.CreateClientSecret,false)
}
resource "azuread_application_registration" "oidc_app" {
  display_name     = var.app_config.DisplayName
  implicit_access_token_issuance_enabled =  try(var.app_config.EnableAccessTokens,null)
  implicit_id_token_issuance_enabled     = try(var.app_config.EnableIdTokens,null)
  logout_url                             = try(var.app_config.SignoutUrl,null)
}

resource "azuread_service_principal" "oidc_sp" {
  client_id    = azuread_application_registration.oidc_app.client_id
  use_existing = true
}


resource "null_resource" "run_powershell_script" {
  triggers = {
    # Trigger based on changes to Web, Spa, and PublicClient redirect URLs

    # Join Web RedirectUrls with both Uri and Index, and fallback to an empty string if missing
    web_redirect_urls = try(join(",", [for url in var.app_config.Web.RedirectUrls : "${url.Uri}-${url.Index}"]), "")

    # Join Spa RedirectUrls (only Uri), fallback to an empty string if missing
    spa_redirect_urls = try(join(",", var.app_config.Spa.RedirectUrls), "")

    # Join PublicClient RedirectUrls (only Uri), fallback to an empty string if missing
    public_client_redirect_urls = try(join(",", var.app_config.PublicClient.RedirectUrls), "")
    enableAccessTokens = try(var.app_config.EnableAccessTokens,"")
    enableIdTokens = try(var.app_config.EnableIdTokens,"")
    force_trigger = var.force_trigger
  }
  provisioner "local-exec" {
  # Execute the PowerShell script and pass the JSON file name
    command = <<EOT
      pwsh -Command "& { .terraform/modules/oidc_apps/update-app.ps1 -jsonFile oidc-app/applications/${var.env}/${var.app_space}/${var.json_file} };exit \$LASTEXITCODE"
    EOT
  }
  depends_on = [azuread_application_registration.oidc_app,azuread_service_principal.oidc_sp]
}


resource "time_rotating" "time_rotation" {
  count = local.CreateClientSecret == true ? 1 : 0
  rotation_years = try(var.app_config.SecretExpiryYears,1)
}

resource "azuread_application_password" "client_secret" {
  count =local.CreateClientSecret == true ? 1 : 0
  application_id = azuread_application_registration.oidc_app.id
  display_name = join("-",[var.app_config.DisplayName,"client-secret"])
  end_date = time_rotating.time_rotation[0].rotation_rfc3339
}