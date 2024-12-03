data "azuread_user" "owners" {
  for_each            = toset(local.unique_owners)  # Ensures unique owner emails
  user_principal_name = each.value
}

resource "azuread_group" "create_groups" {
  for_each = local.create_groups

  display_name             = each.key
  description              = each.value["description"] != null ? each.value["description"] : null
  security_enabled         = true
  prevent_duplicate_names  = true

  # Only add owners if the list is not empty
  owners = length(each.value["owners"]) > 0 ? [for owner_email in each.value["owners"] : data.azuread_user.owners[owner_email].object_id] : []
}

# Lookup the groups specified in AppGroups (assuming they already exist)
data "azuread_group" "existing_groups" {
  for_each  = toset(local.app_groups)
  display_name = each.value
  depends_on = [azuread_group.create_groups]
}

# Lookup user object IDs based on user principal names
data "azuread_user" "users" {
  for_each            = toset(local.user_principal_names)
  user_principal_name = each.value
}

# Generate UUIDs for app roles
resource "random_uuid" "app_role_id" {
  count = length(local.create_app_roles)
}

# Create app roles
resource "azuread_application_app_role" "oidc_roles" {
  count               = length(local.create_app_roles)
  application_id      =  azuread_application_registration.oidc_app.id
  role_id             = random_uuid.app_role_id[count.index].result
  allowed_member_types = ["User"]
  description         = local.create_app_roles[count.index]
  display_name        = local.create_app_roles[count.index]
  value               = local.create_app_roles[count.index]
}

# Assign groups to the application roles
resource "azuread_app_role_assignment" "group_assignments" {
  for_each            = {
    for i, assignment in local.group_role_assignments :
    "${assignment.role}_${assignment.principal}_${i}" => assignment
  }
  principal_object_id = data.azuread_group.existing_groups[each.value.principal].object_id
  app_role_id         = local.app_role_ids[each.value.role]
  resource_object_id  = azuread_service_principal.oidc_sp.object_id
  depends_on          = [ azuread_service_principal.oidc_sp, azuread_group.create_groups]
}

# Assign users to the application roles
resource "azuread_app_role_assignment" "user_assignments" {
  for_each            = {
    for i, assignment in local.user_role_assignments :
    "${assignment.role}_${assignment.principal}_${i}" => assignment
  }
  principal_object_id = data.azuread_user.users[each.value.principal].id
  app_role_id         = local.app_role_ids[each.value.role]
  resource_object_id  = azuread_service_principal.oidc_sp.object_id
  depends_on          = [ azuread_service_principal.oidc_sp, azuread_group.create_groups]
}