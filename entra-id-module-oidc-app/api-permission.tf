locals {
  required_resource_access_map = try({ for rra in var.app_config.RequiredResourceAccess : rra.ResourceApp => rra },{})
  service_principal_object_ids = {
    for rra in local.required_resource_access_map :
    rra.ResourceApp => coalesce(
      try(azuread_service_principal.required_principals[rra.ResourceApp].object_id, null),
      try(data.azuread_service_principal.required_principals[rra.ResourceApp].object_id, null)
    )
  }
  service_principal_client_ids = {
    for rra in local.required_resource_access_map :
    rra.ResourceApp => coalesce(
      try(azuread_service_principal.required_principals[rra.ResourceApp].client_id, null),
      try(data.azuread_service_principal.required_principals[rra.ResourceApp].client_id, null)
    )
  }

  # Local variable to determine the oauth2_permission_scope_ids based on CreatePrincipalifNotexist
  service_principal_oauth2_permission_scope_ids = {
    for rra in local.required_resource_access_map :
    rra.ResourceApp => coalesce(
      try(azuread_service_principal.required_principals[rra.ResourceApp].oauth2_permission_scope_ids, null),
      try(data.azuread_service_principal.required_principals[rra.ResourceApp].oauth2_permission_scope_ids, null)
    )
  }
}

resource "azuread_service_principal" "required_principals" {
  for_each = {
    for rra in local.required_resource_access_map :
    rra.ResourceApp => rra
    if rra.CreatePrincipalifNotexist == true
  }
  client_id    = data.azuread_application_published_app_ids.well_known.result[each.key]
  use_existing = true
}

data "azuread_service_principal" "required_principals" {
  for_each = {
    for rra in local.required_resource_access_map :
    rra.ResourceApp => rra
    if rra.CreatePrincipalifNotexist == false
  }
  client_id    = data.azuread_application_published_app_ids.well_known.result[each.key]
}

resource "azuread_service_principal_delegated_permission_grant" "permission_grants" {
  for_each = {
    for rra in local.required_resource_access_map :
    rra.ResourceApp => rra
    if length([for access in rra.ResourceAccess : access if access.AdminConsent == true]) > 0
  }
  service_principal_object_id          = azuread_service_principal.oidc_sp.object_id
  resource_service_principal_object_id = local.service_principal_object_ids[each.key]

  # Only include permissions where AdminConsent is true
  claim_values = [for access in each.value.ResourceAccess : access.Permission if access.AdminConsent == true]
}

# Create API access for each app dynamically
resource "azuread_application_api_access" "api_access" {
  for_each = local.required_resource_access_map

  application_id = azuread_application_registration.oidc_app.id
  api_client_id  = local.service_principal_client_ids[each.key]

  scope_ids = flatten([for access in each.value.ResourceAccess :
    lookup(local.service_principal_oauth2_permission_scope_ids[each.key], access.Permission, null)
  ])
}