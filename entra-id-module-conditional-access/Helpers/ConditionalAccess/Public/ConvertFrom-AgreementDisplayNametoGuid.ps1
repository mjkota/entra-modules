function ConvertFrom-AgreementDisplayNameToGUID {
    <#
    .SYNOPSIS
    The ConvertFrom-AgreementDisplayNameToGUID command uses a Token from the "Get-AccessToken" command to convert the [array]DisplayNames of Agreements to their respective GUIDs as they exist in the targeted AzureAD tenant. 
    
    .Description
        The command takes the array of displaynames of applications from the JSON file and checks their existence in the targeted AzureAD tenant. 

     Prerequisites
    - Valid Access Token with the minimum following API permissions:
        Agreement.Read.All

        -Optional permission for automatic Agreement creation through use of the -CreateMissingAgreements parameter
        Agreement.Create OR Agreement.Readwrite.All

    .Example 
    [array]$AgreementDisplayNames = "InclusionAgreement1"
    ConvertFrom-AgreementDisplayNameToGUID -AgreementDisplayNames $AgreementDisplayNames -Force $true -AccessToken $AccessToken
    #>
    Param
    (
        [Parameter(Mandatory = $false)]
        [array]$AgreementDisplayNames,
        [Parameter(Mandatory = $true)]
        $AccessToken
    )

    [array]$AgreementGuids = $null  

    Foreach ($AgreementDisplayname in $AgreementDisplaynames) {
        $URI = "https://graph.microsoft.com/v1.0/identityGovernance/termsOfUse/agreements?" + '$filter' + "=displayName eq '$AgreementDisplayname'"
        
        $agreementObject = (Invoke-MgGraphRequest -Uri $uri).value
        
        If ($null -eq $agreementObject) {
            Throw "Agreement: $AgreementDisplayname specified in policy was not found."
        }  
        $AgreementGuids += $agreementObject.id
    }
    Return $AgreementGuids
}




#Below in preparation for when Agreements are supported by the Graph API via application permissions    
#    Foreach ($AgreementDisplayname In $AgreementDisplaynames) {
#        $URI = "https://graph.microsoft.com/beta/Agreements/$AgreementDisplayname"
#        $AgreementObject = Invoke-RestMethod -Method Get -Uri $URI -Headers @{"Authorization" = "Bearer $AccessToken" } 
#        if ($AgreementObject.count -gt 1) {
#            Write-Warning "More than one Object was found for Agreement DisplayName: $LocationDisplayName"
#          }  
#        #Add ID to AgreementDisplaynames
#        $DisplayName = ($AgreementObject.displayName)
#        [array]$AgreementDisplayNames += $DisplayName
#    }
#    Return [array]$AgreementDisplayNames
#}

