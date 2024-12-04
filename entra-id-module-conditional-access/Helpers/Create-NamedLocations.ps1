Param(
    [Parameter(Mandatory = $True)]
    [String]$LocationsFolder,

    [Parameter(Mandatory = $false)]
    $TempDeploy = $false,

    [Parameter(Mandatory = $false)]
    [String]$TempDeployPreFix = "TempDeployToValidate"
)
<#
$LocationsFolder = '.\LocationsFolder'
$TempDeploy = $true
$TempDeployPreFix = "TempDeployToValidate"
#>

#$MSGraphToken = (Get-AzAccessToken -ResourceTypeName MSGraph).Token
#Connect-MgGraph -AccessToken ($MSGraphToken | ConvertTo-SecureString -AsPlainText -Force)

#region import locations templates
Write-Host "Importing locations templates"
$locationFiles = Get-ChildItem -Path $LocationsFolder
$locations = foreach ($file in $locationFiles) {
    $location = (Get-Content -Path $file.FullName -Raw) -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -replace '(?ms)/\*.*?\*/' | ConvertFrom-Json -Depth 10
    $location
}
#endregion

foreach ($namedLocation in $locations) {
    if ($TempDeploy) {
        $namedLocation.displayName = "$($TempDeployPreFix)_$($namedLocation.displayName)"
    }

    $requestBody = $namedLocation | ConvertTo-Json -Depth 3

    $existingLocation = Get-MgBetaIdentityConditionalAccessNamedLocation -Filter "DisplayName eq '$($namedLocation.displayName)'"
    if ($existinglocation) {
        Write-Host "Found existing - trying to update NamedLocation $($namedLocation.displayName)"
        $null = Update-MgBetaIdentityConditionalAccessNamedLocation -NamedLocationId $existingLocation.Id -BodyParameter $requestBody
    }
    else {
        Write-Host "Creating new NamedLocation Name: $($namedLocation.displayName)"
        $null = New-MgBetaIdentityConditionalAccessNamedLocation -BodyParameter $requestBody
    }
}

