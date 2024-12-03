param (
    [string]$jsonFile
)

Function update-pramaeters {
	Param(
		$Settings,
		$BaseParameters
	)

	## Web authentication method configuration
	#region AuthMethodConfig
	$Web = @{
		ImplicitGrantSettings = @{
			EnableAccessTokenIssuance = $settings.EnableAccessTokens
			EnableIdTokenIssuance = $settings.EnableIdTokens
		}
		LogoutUrl = $settings.SignoutUrl
		RedirectUriSettings = $settings.Web.RedirectUrls
	}

	if($settings.Contains("Web")){
		$BaseParameters.Add("Web", $Web)
	}

	## Single page application authentication method configuration
	$Spa = @{
		RedirectUris = $settings.Spa.RedirectUrls
	}

	if($settings.Contains("Spa")){
		$BaseParameters.Add("Spa", $Spa)
	}
	
	## Public Client Application authentication method configuration
	$PublicClient = @{
		RedirectUris = $settings.PublicClient.RedirectUrls
	}

	if($settings.Contains("PublicClient")){
		$BaseParameters.Add("PublicClient", $PublicClient)
	}
	#endregion AuthMethodConfig

	return $BaseParameters
}

$ErrorActionPreference = 'Stop'



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
    $settings = Get-Content -Path $jsonFile | ConvertFrom-Json -Depth 99 -AsHashtable

    if (-not $settings) {
        throw "Failed to parse the JSON file or it is empty."
    }
    Write-Host "Successfully parsed the JSON $jsonFile file."
} catch {
    Write-Error "Error reading or parsing the JSON file '$jsonFile'. Error: $_"
    exit 1
}

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

#Write-Host "Settings: $($settings | ConvertTo-Json -Depth 5)"
$displayName = $settings.DisplayName
$defaultRedirectUri = $settings.DefaultRedirectUrl
Write-Host "DisplayName: $displayName"

#Write-Host "Settings DisplayName: $($settings | ConvertTo-Json -Depth 5)"
# Get the application based on the DisplayName from the JSON
$application = Get-MgApplication -Filter "DisplayName eq '$displayName'"
if ($application) {
    Write-Host "Updating the application configuration for '$displayName'"
    Write-Host "Application ID: $($application.Id)"

    # Create the OICD app.
    $baseParams = @{
#	DisplayName = '$displayName'
	DefaultRedirectUri = $defaultRedirectUri
	Verbose = $true }
    # Compile the parameters necessary for creating the App Registration
    $parameters = update-pramaeters -BaseParameters $baseParams -Settings $settings
    Write-Host "Parameters: $($parameters | ConvertTo-Json -Depth 5)"
    # Update the application configuration
    Update-MgApplication -ApplicationId $application.Id @parameters -Verbose
    if (-not $?) { throw "Failed to update the application configuration for '$displayName'" }
}
else {
    Write-Error "Application with DisplayName '$displayName' not found."
    exit 1
}