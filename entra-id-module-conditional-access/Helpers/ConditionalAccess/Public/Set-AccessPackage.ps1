Function Set-AccessPackage {
  <#
    .SYNOPSIS
    The Set-AccessPackage creates all the necessary resources for creating an Access Package 

    .DESCRIPTION

    .PARAMETER catalogDisplayName
    Displayname of the catalog

    .PARAMETER catalogDescription
    Description of the catalog

    .PARAMETER aadGroupId
    Object ID of the Azure AD group to add as a resource of the access package

    .PARAMETER accessPackageDescription
    Description of the Access Package

    .EXAMPLE
    C:\PS> 

    .NOTES
    DEBUG
      $aadGroupId = $assignmentGroupid
      $aadGroupId = $accessPackGroup.id
      [string[]]$requestorIds = $EntitlementRequestorIds 
      [string[]]$approversIds = $EntitlementApproverIds
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$catalogDisplayName,

    [Parameter(Mandatory = $false)]
    [string]$catalogDescription,

    [Parameter(Mandatory = $true)]
    [guid]$aadGroupId,

    [Parameter(Mandatory = $true)]
    [string]$accessPackageDescription
  )
  $ErrorActionPreference = "stop"

  #region - Get required information
  $aadGroupObject = Get-MgBetaGroup -GroupId $aadGroupId
 
  $catalog = Get-MgbetaEntitlementManagementAccessPackageCatalog -Filter "DisplayName eq '$catalogDisplayName'"
  if ($null -eq $catalog) {
    try {
      New-MgbetaEntitlementManagementAccessPackageCatalog -DisplayName $catalogDisplayName -Description $catalogDescription
    }
    catch {
      if (($Error[0] -notlike "*There's an existing catalog with name*")) {
        throw $Error[0]
      }
      else {
        $catalog = Get-MgbetaEntitlementManagementAccessPackageCatalog -Filter "DisplayName eq '$catalogDisplayName'"
      }
    }
  }
  #endregion - Get required information

  #region - Creating Access Package Resource
  $AccessPackageResource = Get-MgbetaEntitlementManagementAccessPackageCatalogAccessPackageResource -AccessPackageCatalogId $catalog.id -Filter "OriginId eq '$($aadGroupObject.Id)'"

  if ($null -eq $AccessPackageResource) {
    Write-Host "Creating Access Package Resource Request for '$($aadGroupObject.displayName)'"

    $accessPackageResourceRequestBody = New-Object -TypeName Microsoft.Graph.beta.PowerShell.Models.MicrosoftGraphAccessPackageResourceRequest
    $accessPackageResourceRequestBody.CatalogId = $catalog.Id
    $accessPackageResourceRequestBody.requestType = "AdminAdd"
    $accessPackageResourceRequestBody.executeImmediately = $True
    $accessPackageResourceRequestBody.accessPackageResource.displayName = $aadGroupObject.displayName
    $accessPackageResourceRequestBody.accessPackageResource.description = $accessPackageDescription
    $accessPackageResourceRequestBody.accessPackageResource.originId = $aadGroupObject.id
    $accessPackageResourceRequestBody.accessPackageResource.originSystem = "AadGroup"
 
    $i = 1
    $retry = $true
    do {
      $i++
      try {
        $accessPackageResourceRequest = New-MgbetaEntitlementManagementAccessPackageResourceRequest -BodyParameter $accessPackageResourceRequestBody
      }
      catch {
        if ($Error[0] -like "*does not exist or one of its queried reference-property objects are not present") {
          Write-Verbose -Message "Cannot find resource with id $($aadGroupObject.id) yet"
          Start-Sleep $i
          $retry = $true
        }
        else {
          $retry = $false
          Write-Error $Error[0].Exception.Message
        }
      }
    }
    until(($null -ne $accessPackageResourceRequest) -or ($i -lt 8) -or ($retry -eq $false))


    $i = 0
    while (($null -eq $AccessPackageResource) -and ($i -lt 20)) {
      start-sleep 2
      $AccessPackageResource = Get-MgbetaEntitlementManagementAccessPackageCatalogAccessPackageResource -AccessPackageCatalogId $catalog.id -Filter "OriginId eq '$($aadGroupObject.Id)'"
      $i++
    }
  }

  if ($null -eq $AccessPackageResource) {
    Write-Error -Message "Failed to created Access Package Resource"
  }
  #endregion - Creating Access Package Resource

  #region - Create access package if not exist
  $AccessPackage = Get-MgbetaEntitlementManagementAccessPackage -Filter "DisplayName eq '$($AccessPackageResource.DisplayName)'" -Expand 'accessPackageResourceRoleScopes($expand=accessPackageResourceRole)', accessPackageAssignmentPolicies
  if ( $null -eq $AccessPackage ) {
    Write-Host "Creating access package for $($AccessPackageResource.DisplayName)"
    $AccessPackage = New-MgbetaEntitlementManagementAccessPackage -DisplayName $aadGroupObject.displayName -Description $accessPackageDescription -CatalogId $catalog.id
    $i = 0
    while (($null -eq $AccessPackage) -and ($i -lt 20)) {
      Start-Sleep 2
      $AccessPackage = Get-MgbetaEntitlementManagementAccessPackage -Filter "DisplayName eq '$($AccessPackageResource.DisplayName)'" -Expand 'accessPackageResourceRoleScopes($expand=accessPackageResourceRole)', accessPackageAssignmentPolicies
      $i++
    }
  }
  elseif ($AccessPackage.count -gt 1) {
    Write-Error -Message "More than one access package found for '$($AccessPackageResource.displayname)'"
  }
  #endregion - Create access package if not exist

  #region - Create Access Package Resource Role Scope for the access package if not exist
  if ($null -eq $AccessPackage.AccessPackageResourceRoleScopes.id) {
    Write-Host "Creating Access Package Resource Role Scope for '$($AccessPackageResource.DisplayName)'"

    $accessPackageResourceRoleScopeBody = New-Object -TypeName Microsoft.Graph.Beta.PowerShell.Models.MicrosoftGraphAccessPackageResourceRoleScope
    $accessPackageResourceRoleScopeBody.AccessPackageResourceRole.originId = "Member_$($aadGroupObject.Id)"
    $accessPackageResourceRoleScopeBody.AccessPackageResourceRole.displayName = "Member"
    $accessPackageResourceRoleScopeBody.AccessPackageResourceRole.originSystem = "AadGroup"
    $accessPackageResourceRoleScopeBody.AccessPackageResourceRole.accessPackageResource.id = $AccessPackageResource.id
    $accessPackageResourceRoleScopeBody.accessPackageResourceScope.originId = $aadGroupObject.Id
    $accessPackageResourceRoleScopeBody.accessPackageResourceScope.originSystem = "AadGroup"

    $accessPackageResourceRoleScope = New-MgbetaEntitlementManagementAccessPackageResourceRoleScope -BodyParameter $accessPackageResourceRoleScopeBody -AccessPackageId $AccessPackage.id
    $AccessPackage = Get-MgbetaEntitlementManagementAccessPackage -Filter "DisplayName eq '$($AccessPackageResource.DisplayName)'" -Expand 'accessPackageResourceRoleScopes($expand=accessPackageResourceRole)', accessPackageAssignmentPolicies
  }
  #endregion - Create Access Package Resource Role Scope for the access package if not exist
  return $AccessPackage
}