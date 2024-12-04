Param(
    [Parameter(Mandatory = $True)]
    [String]$PoliciesFolder,

    [String]$BackupFilePath =  ".\backup\deletedPolicies.json"
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

#region import policy templates
Write-Host "Importing policy templates"
$Templates = Get-ChildItem -Path $PoliciesFolder
$Policies = foreach ($Item in $Templates) {
    $Policy = Get-Content -Raw -Path $Item.FullName | ConvertFrom-Json
    $Policy
}
#endregion

$allExistingPolicies = Get-MgBetaIdentityConditionalAccessPolicy

$deletedePolicies = @()

foreach ($existingPolicy in $allExistingPolicies) {
    if ($existingPolicy.DisplayName -notin $Policies.displayName) {
        Write-Host("Removing policy: $displayName ID: $($existingPolicy.Id)")
        $deletedePolicies += $existingPolicy
        $null = Remove-MgBetaIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $existingPolicy.Id
    }
}
$deletedePolicies | ConvertTo-Json -Depth 10 | Out-File $BackupFilePath