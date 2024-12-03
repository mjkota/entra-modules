locals {
  create_groups        = try(var.app_config.UserAccess.CreateGroups, {})
  # Collect all groups
  all_groups = flatten([
    for role, data in local.app_roles : 
      coalesce(data.groups, [])
  ])
  app_groups = distinct(local.all_groups)
  # Collect all users
  all_users = flatten([
    for role, data in local.app_roles : 
      coalesce(data.users, [])
  ])
  user_principal_names = distinct(local.all_users)
  all_owners = flatten([
    for group_key, group in local.create_groups : coalesce(group.owners, [])
  ])
  # Ensure unique owners, even if the list is empty
  unique_owners = distinct(local.all_owners)

  app_roles            = try(var.app_config.UserAccess.AppRoles, {})
  create_app_roles      = try(var.app_config.UserAccess.CreateAppRoles,[])
  // Flatten user assignments into a single map
  user_role_assignments = flatten([
    for role, config in local.app_roles : [
      for user in config.users : {
        role = role
        principal = user
        type = "user"
      }
    ]
  ])
  // Flatten group assignments into a single map
  group_role_assignments = flatten([
    for role, config in local.app_roles : [
      for group in config.groups : {
        role = role
        principal = group
        type = "group"
      }
    ]
  ])
  
  # Create a set of roles created from the resource block
  created_role_ids = {
    for i, role in local.create_app_roles :
    role => azuread_application_app_role.oidc_roles[i].role_id
  }

  # Combine both created and existing roles, prioritizing created roles
  app_role_ids = merge(
    local.created_role_ids
  )
}