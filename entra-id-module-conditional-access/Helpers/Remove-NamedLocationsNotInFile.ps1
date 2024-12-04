Param(
    [Parameter(Mandatory = $True)]
    [String]$LocationsFolder,

    [String]$BackupFilePath =  ".\backup\deletedLocations.json"
)

# Retrieve the client secret and other credentials from environment variables
$clientSecretPlainText = $env:ARM_CLIENT_SECRET
$clientId = $env:ARM_CLIENT_ID
$tenantId = $env:ARM_TENANT_ID

# Ensure credentials are present
if (-not $clientSecretPlainText -or -not $clientId -or -not $tenantId) {
    Write-Error "ARM_CLIENT_SECRET, ARM_CLIENT_ID, or ARM_TENANT_ID environment variables are missing."
    exit 1
}

# Convert client secret to secure string and create credentials
$clientSecret = ConvertTo-SecureString $clientSecretPlainText -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($clientId, $clientSecret)

# Connect to Microsoft Graph
try {
    Connect-MgGraph -NoWelcome -ClientSecretCredential $credential -TenantId $tenantId
    Write-Host "Connected to Microsoft Graph successfully."
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Error: $_"
    exit 1
}

#region import location templates
Write-Host "Importing location templates"
$Templates = Get-ChildItem -Path $LocationsFolder
$LocationsObjects = foreach ($Item in $Templates) {
    $location = Get-Content -Raw -Path $Item.FullName | ConvertFrom-Json
    $location
}
#endregion

$allExistingLocations = Get-MgBetaIdentityConditionalAccessNamedLocation # | Where-Object { $_.DisplayName -ne "All Compliant Network locations" }

$deletedeLocations = @()
foreach ($existingLocation in $allExistingLocations) {
    if ($existingLocation.displayName -notin $LocationsObjects.displayName) {
        Write-Host("Removing named location: $($existingLocation.displayName) ID: $($existingLocation.Id)")
        $deletedeLocations += $existingLocation
        $null = Remove-MgBetaIdentityConditionalAccessNamedLocation -NamedLocationId $existingLocation.id
    }
}
if (!(Test-Path (Split-Path $BackupFilePath ))) {
    New-Item -ItemType Directory -Path (Split-Path $BackupFilePath )
}
$deletedeLocations | ConvertTo-Json -Depth 10 | Out-File $BackupFilePath