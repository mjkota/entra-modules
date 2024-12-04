Param(
  [Parameter(Mandatory = $True)]
  [String]$PoliciesFolder,

  [Parameter(Mandatory = $True)]
  [String]$globalConfigFile,

  [Parameter(Mandatory = $false)]
  $TempDeploy = $false,

  [Parameter(Mandatory = $false)]
  [String]$TempDeployPreFix = "TempDeployToValidate",

  [Parameter(Mandatory = $false)]
  [bool]$TestWithGroupsCreated = $false,

  [Parameter(Mandatory = $True)]
  [String]$AccessToken
)

<# Debug
  $PoliciesFolder = '.\Policies'
  $globalConfigFile = '.\globalConfig.json'
  $TempDeploy = $true
  $TempDeployPreFix = "TempDeployToValidate"
#>

Import-Module "$PSScriptRoot/ConditionalAccess"

#$AccessToken = (Get-AzAccessToken -ResourceTypeName MSGraph).Token
#Connect-MgGraph -AccessToken ($AccessToken | ConvertTo-SecureString -AsPlainText -Force)

# Connect-MgGraph -AccessToken $AccessToken -scopes @('Policy.Read.All', 'Policy.ReadWrite.ConditionalAccess', 'Application.Read.All')

#region import policies
$policyFiles = Get-ChildItem -Path $PoliciesFolder
Write-Host ("Found: " + $policyFiles.Count + " to import.")
$Policies = foreach ($Item in $policyFiles) {
  $Policy = (Get-Content -Path $Item.FullName -Raw) -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -replace '(?ms)/\*.*?\*/' | ConvertFrom-Json -Depth 10
  $Policy
}
#endregion

$globalConfig = (Get-Content -Path $globalConfigFile -Raw) -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -replace '(?ms)/\*.*?\*/' | ConvertFrom-Json -Depth 10

#Get existing policies from tenant
$ExistingPolicies = Get-ConditionalAccessPolicy -AccessToken $AccessToken -ConvertGUIDs $false
Write-Host ("Found: " + $ExistingPolicies.Count + " existing policies.")

#region create or update policies
# $Policy = $Policies | out-gridview -passthru
foreach ($Policy in $Policies) {
  Write-Host "Processing: '$($Policy.DisplayName)'........"
  #If temp deployment then replace values
  # users and groups are replaced with empty arrays since personagroups are not created in validate step
  if ($TempDeploy) {
    $Policy.displayName = "$($TempDeployPreFix)_$($Policy.displayName)"
    $Policy.state = "disabled"
  }
  if (($TempDeploy) -and (!$TestWithGroupsCreated)) {
    $Policy.conditions.users.excludeUsers = @()
    $Policy.conditions.users.includeUsers = @('None')
    $Policy.conditions.users.includeGroups = @()
    $Policy.conditions.users.excludeGroups = @()
  }


  #region - Convert DisplayNames to GUIDS
  #Get GUIDs for the DisplayNames of the Groups from the Powershell-representation of the JSON, from AzureAD through use of Microsoft Graph. 
  [array]$InclusionGroupsGuids = ConvertFrom-GroupDisplayNameToGUID -GroupDisplayNames ($Policy.conditions.users.includeGroups) -AccessToken $AccessToken
  [array]$ExclusionGroupsGuids = ConvertFrom-GroupDisplayNameToGUID -GroupDisplayNames ($Policy.conditions.users.excludeGroups) -AccessToken $AccessToken
  #Get GUIDs for the DisplayName of the Users from the Powershell representation of the JSON, from AzureAD through use of Microsoft Graph.
  [array]$InclusionUsersGuids = ConvertFrom-UserDisplayNameToGUID -UserDisplayNames ($Policy.conditions.users.includeUsers) -AccessToken $AccessToken 
  [array]$ExclusionUsersGuids = ConvertFrom-UserDisplayNameToGUID -UserDisplayNames ($Policy.conditions.users.ExcludeUsers) -AccessToken $AccessToken 
  #Get GUIDs for the DisplayName of the Application from the Powershell representation of the JSON, from AzureAD through use of Microsoft Graph.
  [array]$InclusionApplicationGuids = ConvertFrom-ApplicationDisplayNametoGUID -ApplicationDisplayNames ($Policy.conditions.applications.includeApplications) -AccessToken $AccessToken 
  [array]$ExclusionApplicationGuids = ConvertFrom-ApplicationDisplayNametoGUID -ApplicationDisplayNames ($Policy.conditions.applications.excludeApplications) -AccessToken $AccessToken 
  #Get GUIDs for the DisplayName of the Roles from the Powershell representation of the JSON, from AzureAD through use of Microsoft Graph.
  [array]$InclusionRoleGuids = ConvertFrom-RoleDisplayNametoGUID -RoleDisplayNames ($Policy.conditions.users.includeRoles) -AccessToken $AccessToken 
  [array]$ExclusionRoleGuids = ConvertFrom-RoleDisplayNametoGUID -RoleDisplayNames ($Policy.conditions.users.excludeRoles) -AccessToken $AccessToken 
  #Get GUIDs for the DisplayName of the Locations from the Powershell representation of the JSON, from AzureAD through the use of Microsoft Graph. 
  [array]$InclusionLocationGuids = ConvertFrom-LocationDisplayNameToGUID -LocationDisplayNames ($Policy.conditions.locations.includeLocations) -AccessToken $AccessToken 
  [array]$ExclusionLocationGuids = ConvertFrom-LocationDisplayNameToGUID -LocationDisplayNames ($Policy.conditions.locations.ExcludeLocations) -AccessToken $AccessToken 
  #Get GUIds for the DisplayName of TermsofUse (Agreement-object) in the targeted tenant. The Convert.Json file to function since Graph does not support this functionality yet. 
  [array]$AgreementGuids = ConvertFrom-AgreementDisplayNameToGUID -AgreementDisplayNames ($Policy.grantControls.termsOfUse) -AccessToken $AccessToken

 
  #Convert the Displaynames in the Powershell-object to the GUIDs.  
  If ($InclusionGroupsGuids) {
    $Policy.conditions.users.includeGroups = $InclusionGroupsGuids
  }
  If ($ExclusionGroupsGuids) {
    $Policy.conditions.users.excludeGroups = $ExclusionGroupsGuids
  }
  If ($InclusionUsersGuids) { 
    $Policy.conditions.users.includeUsers = $InclusionUsersGuids
  }
  If ($ExclusionUsersGuids) { 
    $Policy.conditions.users.ExcludeUsers = $ExclusionUsersGuids
  }
  if (($Policy.conditions.applications | Get-Member -MemberType NoteProperty).Name -contains 'includeApplications') {
    If ($inclusionApplicationGuids) { 
      $Policy.conditions.applications.includeApplications = $InclusionApplicationGuids
    }
    else {
      [string[]]$Policy.conditions.applications.includeApplications = 'none'
    }
  }
  If ($ExclusionApplicationGuids) { 
    $Policy.conditions.applications.excludeApplications = $ExclusionApplicationGuids
  }
  If ($InclusionRoleGuids) { 
    $Policy.conditions.users.includeRoles = $InclusionRoleGuids
  } 
  If ($ExclusionRoleGuids) { 
    $Policy.conditions.users.excludeRoles = $ExclusionRoleGuids 
  }
  If ($InclusionLocationGuids) { 
    $Policy.conditions.locations.includeLocations = $InclusionLocationGuids
  } 
  If ($ExclusionLocationGuids) { 
    $Policy.conditions.locations.excludeLocations = $ExclusionLocationGuids 
  }
  If ($AgreementGuids) { 
    $Policy.grantControls.termsOfUse = $AgreementGuids 
  }
  #endregion - Convert DisplayNames to GUIDS
    
  # Add global values
  foreach ($usersProperty in $Policy.conditions.users.PSObject.Properties) {
    foreach ($globalConfigProperty in $globalConfig.PSObject.Properties) {
      if ($usersProperty.Name -eq $globalConfigProperty.Name) {
        $Policy.conditions.users.$($usersProperty.Name) += $globalConfigProperty.Value
      }
    }
  }

  #Remove duplicate it can occur when global config is addded.
  foreach ($usersPropertie in $Policy.conditions.users.PSObject.Properties) {
    if ($Policy.conditions.users.$($usersPropertie.Name)) {
      $Policy.conditions.users.$($usersPropertie.Name) = [Array]($Policy.conditions.users.$($usersPropertie.Name) | Select-Object -Unique)
    }
  }
    
  #Remove unnecessary objects if include contains ALL
  $all = @("All")
  if ($Policy.conditions.users.includeUsers -contains "All") { $Policy.conditions.users.includeUsers = $All }
  if ($Policy.conditions.users.includeGroups -contains "All") { $Policy.conditions.users.includeGroups = $All }
  if ($Policy.conditions.users.includeRoles -contains "All") { $Policy.conditions.users.includeRoles = $All }

  #Create or update
  $requestBody = $Policy | ConvertTo-Json -Depth 10

  $existingPolicy = Get-MgBetaIdentityConditionalAccessPolicy -Filter "DisplayName eq '$($Policy.DisplayName)'"    
  if ($existingPolicy) {
    Write-Host "Found existing - trying to update policy $($Policy.DisplayName)"
    $null = Update-MgBetaIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $existingPolicy.id -BodyParameter $requestBody
  }
  else {
    Write-Host "Creating new policy Name: $($Policy.DisplayName)"
    $null = New-MgBetaIdentityConditionalAccessPolicy -BodyParameter $requestBody
  }
}
#endregion

#region disconnect
try { Disconnect-MgGraph -ErrorAction SilentlyContinue }catch {}
#endregion
