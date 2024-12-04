Function Set-AccessPackagePolicy {
  <#
    .SYNOPSIS
    The Set-AccessPackagePolicy creates or updates Access Package policies
    
    .DESCRIPTION
    
    .PARAMETER accessPackageId
    The ID of the Access Package

    .PARAMETER requestorIds
    Object Ids of groups or users that can request the package

    .PARAMETER approversIds
    Object Ids of groups or users that can approve a request to the package

    .PARAMETER IsApprovalRequiredForExtension
    Can a requester extend without approval - Default value $True

    .PARAMETER accessPackageAssignmentDuration
    Assignment of package in ISO8601 format

    .PARAMETER CanExtend
    Request can request extention - Default value $True

    .PARAMETER accessPackageDescription
    Description of the Access Package

    .EXAMPLE
    WIP

    .NOTES  
    DEBUG
      $aadGroupId = $assignmentGroup
      $aadGroupId = $accessPackGroup.id
      [string[]]$requestorIds = $EntitlementRequestorIds 
      [string[]]$approversIds = $EntitlementApproverIds
  #>

  param(
    [Parameter(Mandatory = $true)]
    [string]$accessPackageId,

    [Parameter(Mandatory = $true)]
    [string]$policyName,

    [Parameter(Mandatory = $true)]
    [string]$policyDescription,

    [Parameter(Mandatory = $true)]
    [string[]]$requestorIds,
    
    [Parameter(Mandatory = $true)]
    [string[]]$approversIds,

    [parameter(Mandatory = $false)]
    [boolean]$IsApprovalRequiredForExtension = $true,
    
    [Parameter(Mandatory = $true)]
    [string]$accessPackageAssignmentDuration,
    
    [Parameter(Mandatory = $false)]
    [boolean]$CanExtend = $true
  )
  $ErrorActionPreference = "stop"

  #region - Get required information
  
  #Get approvers
  $approversBodyObject = @{
    ids   = $approversIds
    types = "user", "group"
  }
  $approversResponse = Invoke-MgGraphRequest -method post -uri 'https://graph.microsoft.com/v1.0/directoryObjects/getByIds' -body ($approversBodyObject | ConvertTo-Json ) -contentType 'application/json'
  $approvers = $approversResponse.Value | select-object '@odata.type', displayname, id

  #Get requestors
  $requestorBodyObject = @{
    ids   = $requestorIds
    types = "user", "group"
  }
  $requestorResponse = Invoke-MgGraphRequest -method post -uri 'https://graph.microsoft.com/v1.0/directoryObjects/getByIds' -body ($requestorBodyObject | ConvertTo-Json ) -contentType 'application/json'
  $requestors = $requestorResponse.Value | select-object '@odata.type', displayname, id
  #endregion - Get required information

  #region - Create access package if not exist
  $AccessPackage = Get-MgBetaEntitlementManagementAccessPackage -AccessPackageId $accessPackageId -ExpandProperty 'AccessPackageAssignmentPolicies'
  if ( $null -eq $AccessPackage ) {
    Write-Error -Message "No access package found for id '$accessPackageId'"
  }
  #endregion - Create access package if not exist

  #region - Create Access Package Assignment Policies
  if ($accessPackage.AccessPackageAssignmentPolicies.DisplayName -notcontains $policyName) {
    Write-Host "Creating Access Package Assignment Policy '$policyName' for '$($AccessPackage.DisplayName)'"
    $AccessPackageAssignmentPolicyBody = New-Object -TypeName Microsoft.Graph.beta.PowerShell.Models.MicrosoftGraphAccessPackageAssignmentPolicy

    $AccessPackageAssignmentPolicyBody.AccessPackage.Id = $AccessPackage.Id
    $AccessPackageAssignmentPolicyBody.DisplayName = $policyName #"Specific groups can request with approval"#
    $AccessPackageAssignmentPolicyBody.Description = "Members of '$($requestors.DisplayName -join ', ')' can request eligibility to access resource"#
    $AccessPackageAssignmentPolicyBody.CanExtend = $CanExtend
    $AccessPackageAssignmentPolicyBody.AccessReviewSettings = $null
  
    # Allowed Requestors
    $requestorsSet = @()
    $requestors | ForEach-Object {
      if ($_.'@odata.type' -like '*#microsoft.graph.group*') { $type = "#microsoft.graph.groupMembers" }
      if ($_.'@odata.type' -like '*#microsoft.graph.user*') { $type = "#microsoft.graph.singleUser" }
      $requestor = New-Object -TypeName Microsoft.Graph.Beta.PowerShell.Models.MicrosoftGraphUserSet
      $requestor.IsBackup = $false
      $requestor.AdditionalProperties.Add('@odata.type', $type)
      $requestor.AdditionalProperties.Add('id', $_.id)
      $requestor.AdditionalProperties.Add('description', "Members of $($_.displayname)")
      $requestorsSet += $requestor
    }

    # RequestorSettings
    $AccessPackageAssignmentPolicyBody.RequestorSettings.AcceptRequests = $true
    $AccessPackageAssignmentPolicyBody.RequestorSettings.ScopeType = 'SpecificDirectorySubjects'
    $AccessPackageAssignmentPolicyBody.RequestorSettings.AllowedRequestors = $requestorsSet

    # RequestApprovalSettings
    $AccessPackageAssignmentPolicyBody.RequestApprovalSettings.IsApprovalRequired = ($approversIds.Count -gt 0)
    $AccessPackageAssignmentPolicyBody.RequestApprovalSettings.IsApprovalRequiredForExtension = $IsApprovalRequiredForExtension
    $AccessPackageAssignmentPolicyBody.RequestApprovalSettings.IsRequestorJustificationRequired = $true
    $AccessPackageAssignmentPolicyBody.RequestApprovalSettings.ApprovalMode = "SingleStage"

    $approvStage = New-Object -TypeName Microsoft.Graph.Beta.PowerShell.Models.MicrosoftGraphApprovalStage
    $approvStage.ApprovalStageTimeOutInDays = 14
    $approvStage.IsApproverJustificationRequired = $true
    $approvStage.IsEscalationEnabled = $false

    # Approvers
    $approversSet = @()
    $approvers | ForEach-Object {
      if ($_.'@odata.type' -like '*#microsoft.graph.group*') { $type = "#microsoft.graph.groupMembers" }
      if ($_.'@odata.type' -like '*#microsoft.graph.user*') { $type = "#microsoft.graph.singleUser" }
      $approver = New-Object -TypeName Microsoft.Graph.Beta.PowerShell.Models.MicrosoftGraphUserSet
      $approver.IsBackup = $false
      $approver.AdditionalProperties.Add('@odata.type', $type)
      $approver.AdditionalProperties.Add('id', $_.id)
      $approver.AdditionalProperties.Add('description', "Members of $($_.displayname)")
      $approversSet += $approver
    }

    $approvStage.PrimaryApprovers = $approversSet
    $AccessPackageAssignmentPolicyBody.RequestApprovalSettings.ApprovalStages = $approvStage

    $AccessPackageAssignmentPolicy = New-MgBetaEntitlementManagementAccessPackageAssignmentPolicy -BodyParameter $AccessPackageAssignmentPolicyBody
    Start-Sleep 5

    $AccessPackageAssignmentPolicyResponse = Invoke-MgGraphRequest -Method GET -uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/assignmentPolicies/$($AccessPackageAssignmentPolicy.Id)?`$expand=AccessPackage(`$select=id)"
    if ($accessPackageAssignmentDuration -ne "Never") {
      $AccessPackageAssignmentPolicyResponse.expiration.Duration = $accessPackageAssignmentDuration
      $AccessPackageAssignmentPolicyResponse.expiration.type = "afterDuration"
    }
    else {
      $AccessPackageAssignmentPolicyResponse.expiration.type = "noExpiration"
      $AccessPackageAssignmentPolicyResponse.expiration.Duration = $null
    }
    $jsonBody = $AccessPackageAssignmentPolicyResponse | Select-Object id, displayName, description, allowedTargetScope, SpecificAllowedTargets, automaticRequestSettings, expiration, requestorSettings, requestApprovalSettings, accessPackage | ConvertTo-Json -Depth 10

    $AccessPackageAssignmentPolicyResponse = Invoke-MgGraphRequest -Method PUT -Body $jsonBody -uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/assignmentPolicies/$($AccessPackageAssignmentPolicy.Id)"
    
  }
  else {
    $AccessPackageAssignmentPolicyResponse = (Invoke-MgGraphRequest -Method GET -uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/assignmentPolicies/$(($accessPackage.AccessPackageAssignmentPolicies | Where-Object {$_.DisplayName -eq $policyName}).Id)" -OutputType PSObject) #`$expand=AccessPackage(`$select=id)"
    
    # Find current approvers
    $currentApprovers = @()
    foreach ($approv in $AccessPackageAssignmentPolicyResponse.requestApprovalSettings.stages[0].primaryApprovers) {
      if ($approv."@odata.type" -like '*group*') { $currentApprovers += $approv.groupId }
      else { $currentApprovers += $approv.userId }
    }
    
    if (
      (($accessPackageAssignmentDuration -eq 'Never') -and ($AccessPackageAssignmentPolicyResponse.expiration.type -ne 'noExpiration')) -or
      (($accessPackageAssignmentDuration -ne 'Never') -and ($AccessPackageAssignmentPolicyResponse.expiration.duration -ne $accessPackageAssignmentDuration)) -or
      ($null -ne (Compare-Object -ReferenceObject ($AccessPackageAssignmentPolicyResponse.specificAllowedTargets[0].groupId) -DifferenceObject $requestors.id )) -or
      ($AccessPackageAssignmentPolicyResponse.requestApprovalSettings.isApprovalRequiredForAdd -ne ($approversIds.Count -gt 0)) -or
      ($AccessPackageAssignmentPolicyResponse.requestApprovalSettings.isApprovalRequiredForUpdate -ne $IsApprovalRequiredForExtension) -or
      ($null -ne (Compare-Object -ReferenceObject $currentApprovers -DifferenceObject $approvers.Id ))
    ) {
      Write-Host "Updating Access Package Assignment Policies for '$($AccessPackageAssignmentPolicyResponse.displayName)'"

      # Allowed Requestors
      $requestorsSet = @{}
      [array]$requestorsSet = $requestors | ForEach-Object {
        if ($_.'@odata.type' -like '*#microsoft.graph.group*') { $type = "#microsoft.graph.groupMembers"; $idName = 'groupId' }
        if ($_.'@odata.type' -like '*#microsoft.graph.user*') { $type = "#microsoft.graph.singleUser"; $idName = 'userId' }
        $requestor = @{
          'isBackup'    = $false
          '@odata.type' = $type
          $idname       = $_.id
          'description' = "Members of $($_.displayname)"
        }
        $requestor
      }

      # Approvers
      $approversSet = $null
      [array]$approversSet = $approvers | ForEach-Object {
        if ($_.'@odata.type' -like '*#microsoft.graph.group*') { $type = "#microsoft.graph.groupMembers"; $idName = 'groupId' }
        if ($_.'@odata.type' -like '*#microsoft.graph.user*') { $type = "#microsoft.graph.singleUser"; $idName = 'userId' }
        $approver = @{
          'isBackup'    = $false
          '@odata.type' = $type
          $idname       = $_.id
          'description' = "Members of $($_.displayname)"
        }
        $approver
      }

      $AccessPackageAssignmentPolicyResponse.SpecificAllowedTargets = $requestorsSet
      $AccessPackageAssignmentPolicyResponse.Description = "Members of '$($requestors.DisplayName -join ', ')' can request eligibility to access resource"
      $AccessPackageAssignmentPolicyResponse.requestApprovalSettings.isApprovalRequiredForAdd = ($approversIds.Count -gt 0)
      $AccessPackageAssignmentPolicyResponse.requestApprovalSettings.isApprovalRequiredForUpdate = $IsApprovalRequiredForExtension
      $AccessPackageAssignmentPolicyResponse.requestApprovalSettings.stages[0].primaryApprovers = $approversSet      
      
      if ($accessPackageAssignmentDuration -gt 0) {
        $AccessPackageAssignmentPolicyResponse.expiration.Duration = $accessPackageAssignmentDuration
        # $AccessPackageAssignmentPolicyResponse.expiration.duration = "P$accessPackageAssignmentDuration`D"
      }
      else {
        $AccessPackageAssignmentPolicyResponse.expiration.type = "noExpiration"
        $AccessPackageAssignmentPolicyResponse.expiration.Duration = $null
      }
      $jsonBody = $AccessPackageAssignmentPolicyResponse | Select-Object id, displayName, description, allowedTargetScope, SpecificAllowedTargets, automaticRequestSettings, expiration, requestorSettings, requestApprovalSettings, accessPackage | ConvertTo-Json -Depth 10

      $AccessPackageAssignmentPolicyResponse = Invoke-MgGraphRequest -Method PUT -Body $jsonBody -uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/assignmentPolicies/$($AccessPackageAssignmentPolicyResponse.id)"
      # "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/assignmentPolicies/$($AccessPackage.AccessPackageAssignmentPolicies.Id)"
    }
  }
  #endregion - Create Access Package Assignment Policies

}