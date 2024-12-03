param (
    [string]$jsonFile
)

# Check if jsonFile is provided
if (-not $jsonFile) {
    Write-Error "The jsonFile parameter is required."
    exit 1
}
 
# Check if the specified file exists
if (-not (Test-Path -Path $jsonFile)) {
    Write-Error "The specified JSON file does not exist: $jsonFile"
    exit 1
}
# Try to read and parse the JSON file safely
try {
    $jsonContent = Get-Content -Path $jsonFile -ErrorAction Stop
    $appConfig = $jsonContent | ConvertFrom-Json -Depth 99 -AsHashtable
    if (-not $appConfig) {
        throw "Failed to parse the JSON file or it is empty."
    }
    Write-Host "Successfully parsed the JSON $jsonFile file."
} catch {
    Write-Error "Error reading or parsing the JSON file '$jsonFile'. Error: $_"
    exit 1
}

$displayName = $appConfig.DisplayName
$replyUrls = $appConfig.BasicSamlServicePrincipalConfiguration.replyUrls
$customSecurityAttributes = $appConfig.CustomSecurityAttributes
$logoutUrl = $appConfig.BasicSamlServicePrincipalConfiguration.logoutUrl

# Install Microsoft.Graph.Applications module if not already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Applications)) {
    Install-Module -Name Microsoft.Graph.Applications -Force
    if ($?) {
        Write-Host "Microsoft.Graph.Applications module installed successfully."
    } else {
        Write-Error "Failed to install Microsoft.Graph.Applications module."
        exit 1
    }
} else {
    Write-Host "Microsoft.Graph.Applications module is already installed."
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
    Connect-MgGraph -NoWelcome -ClientSecretCredential $credential -TenantId $tenantId
    Write-Host "Connected to Microsoft Graph successfully."
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Error: $_"
    exit 1
}

# Get the application based on the DisplayName from the JSON
$application = Get-MgApplication -Filter "DisplayName eq '$displayName'"
$servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$displayName'"

if ($application -and $servicePrincipal) {
    Write-Host "Updating the application configuration for $displayName"
    Write-Host "Application ID: $($application.Id)"
    Write-Host "Service Principal ID: $($servicePrincipal.Id)"

    # Prepare parameters for updating the application
    $params = @{
        Web = @{
            logoutUrl           = $logoutUrl
            RedirectUriSettings = $replyUrls
        }
        DefaultRedirectUri = $appConfig.BasicSamlServicePrincipalConfiguration.defaultReplyUrl
        IdentifierUris = $appConfig.BasicSamlServicePrincipalConfiguration.identifier
    }

    # Update the application configuration
    Update-MgApplication -ApplicationId $application.Id -BodyParameter $params -Verbose
    if (-not $?) { throw "Failed to update the application configuration for $displayName" }

    # Update Service Principal configuration
    $params = @{
        ReplyUrls = $replyUrls.Uri # Reply URL (Assertion Consumer Service URL)
    }
    Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -BodyParameter $params -Verbose
    if (-not $?) { throw "Failed to update the service principal for $displayName" }

    # Add custom security attributes
    Write-Host "Adding custom security attributes"
    Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -CustomSecurityAttributes $customSecurityAttributes
    if (-not $?) { throw "Failed to add custom security attributes for $displayName" }

} else {
    Write-Error "Application or Service Principal with DisplayName '$displayName' not found."
    exit 1
}

#region disconnect
try { Disconnect-MgGraph -ErrorAction SilentlyContinue }catch {}
#endregion