param (
    [Parameter(Mandatory=$true)]
    [string]$path,

    [Parameter(Mandatory=$false)]
    [string]$deleteUnknownPolicies ="false"
)


# Define the modules and their required versions
$modules = @(
    @{Name = "Microsoft.Graph.Beta.Applications"; Version = "2.11.1"},
    @{Name = "Microsoft.Graph.Beta.Identity.DirectoryManagement"; Version = "2.11.1"},
    @{Name = "Microsoft.Graph.Beta.Identity.SignIns"; Version = "2.11.1"},
    @{Name = "Microsoft.Graph.Beta.Identity.Governance"; Version = "2.11.1"},
    @{Name = "Microsoft.Graph.Beta.Groups"; Version = "2.11.1"}
)

# Iterate through the modules to check if they are installed
foreach ($module in $modules) {
    $installedModule = Get-InstalledModule -Name $module.Name -ErrorAction SilentlyContinue
    
    if ($installedModule -and ($installedModule.Version -eq $module.Version)) {
        Write-Host "$($module.Name) version $($module.Version) is already installed."
    } else {
        Write-Host "Installing $($module.Name) version $($module.Version)..."
        try {
            # Attempt to install the module
            Install-Module -Name $module.Name -Force -Scope CurrentUser -RequiredVersion $module.Version -SkipPublisherCheck -ErrorAction Stop

            Write-Host "$($module.Name) installed successfully."
        }
        catch {
            # Catch and handle errors
            Write-Host "Error installing $($module.Name): $_" -ForegroundColor Red
        }
    }
}

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
    Connect-MgGraph -NoWelcome -ClientSecretCredential $credential -TenantId $tenantId -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph successfully."
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Error: $_"
    exit 1
}

### Get the token since this has been used in many other part of scripts
$scope = "https://graph.microsoft.com/.default"  # Scope for Microsoft Graph API

# Create the body for the request
$body = @{
    client_id     = $clientId
    scope         = $scope
    client_secret = $clientSecretPlainText
    grant_type    = "client_credentials"
}

# Define the token request URI
$tokenUri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

# Make the request to get the access token
$tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUri -ContentType "application/x-www-form-urlencoded" -Body $body

# Extract the access token from the response
$AccessToken = $tokenResponse.access_token
###############################################

<#
$apiPermissions = @("Application.Read.All", 
  "Policy.Read.All", 
  "Policy.ReadWrite.ConditionalAccess",
  "RoleManagement.Read.Directory",
  "User.Read.All"
  "Group.ReadWrite.All"
  "Agreement.Read.All"
  "Agreement.ReadWrite.All"
  "EntitlementManagement.ReadWrite.All"
)
#>

## variables:
$PoliciesFolder = "$path/Policies"
$LocationsFolder = "$path/Locations"
$globalConfigFile = "$path/globalConfig.json"
#$namedLocationsFileName = "namedLocations.json"
#$TestWithGroupsCreated = $false


#### stage deployConditionalAccess ####################

.\Helpers\Create-NamedLocations.ps1 -LocationsFolder $LocationsFolder

.\Helpers\Create-ConditionalAccessPolicies.ps1 -PoliciesFolder $PoliciesFolder -globalConfigFile $globalConfigFile -AccessToken $AccessToken


### clean up unknown ###
<#
Warning, below will remove policies and locations not present in this framework.
#>
if ($deleteUnknownPolicies -eq "true") {
    Write-Output "true" 
mkdir .\backup -ErrorAction SilentlyContinue
.\Helpers\Remove-ConditionalAccessPoliciesNotInFolder.ps1 -PoliciesFolder $PoliciesFolder `
      -BackupFilePath '.\backup\deletedPolicies.json'
.\Helpers\Remove-NamedLocationsNotInFile.ps1 -LocationsFolder $LocationsFolder `
      -BackupFilePath '.\backup\deletedLocations.json'

}
else {
Write-Host "Delete Unknown Policies is set to false"
}
