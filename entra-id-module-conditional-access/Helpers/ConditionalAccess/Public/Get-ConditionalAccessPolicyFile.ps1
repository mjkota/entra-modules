function Get-ConditionalAccessPolicyFile {
    [cmdletbinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        $AccessToken,
        [Parameter(Mandatory = $true)]
        $Path,
        [Parameter(Mandatory = $false)]
        $Id = $false,
        [Parameter(Mandatory = $false)]
        $DisplayName = $false,
        [Parameter(Mandatory = $false)]
        $ConvertGUIDs = $true,
        [Parameter(Mandatory = $false)]
        $PathConvertFile 
        
    )
    
    [Array]$Policies = Get-ConditionalAccessPolicy -AccessToken $AccessToken -DisplayName $DisplayName -Id $Id -ConvertGUIDs $ConvertGUIDs -PathConvertFile $PathConvertFile

    Foreach ($Policy in $Policies) {
        $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
        $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
        $fileName = ($policy.DisplayName -replace $re)

        $temp = $policy #.ToJsonString() | ConvertFrom-Json #convert to PSCustomObject
        $temp.PSObject.Properties.Remove("id") #DisplayName is used to identify insted of Id 
        $temp.PSObject.Properties.Remove("createdDateTime") #read only field
        $temp.PSObject.Properties.Remove("modifiedDateTime") #Read only field

        $temp | ConvertTo-Json -Depth 10 | Out-File "$Path\$fileName.json"


        # #Check for characters that can't be used in filenames
        # $FileName = ($Policy.displayName + ".json").Replace(":", "").Replace("\", "").Replace("*", "").Replace("<", "").Replace(">", "").Replace("/", "")
        # $Json = $Policy | ConvertTo-Json -Depth 3
        # $Json | Out-file ($Path + "\" + $FileName)
    }
}
