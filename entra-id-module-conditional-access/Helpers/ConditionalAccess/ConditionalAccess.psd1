﻿#
# Module manifest for module 'ConditionalAccess'
#
# Generated by: Maatschap Fortigi
#
# Generated on: 16/06/2020
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'ConditionalAccess.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.202'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = 'd11aa11b-ee4f-43ce-8c07-5d2ce4fa4533'

    # Author of this module
    Author            = 'William Overweg & Wim van den Heijkant'

    # Company or vendor of this module
    CompanyName       = 'Fortigi'

    # Copyright statement for this module
    Copyright         = '(c) 2020 Fortigi.'

    # Description of the functionality provided by this module
    Description       = 'This module allows you to manage Conditional Access Policy from PowerShell. Is uses the Microsoft Grap API. For more info https://github.com/Fortigi/ConditionalAccess'

    # Minimum version of the Windows PowerShell engine required by this module
    # PowerShellVersion = ''

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @(
    )

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export 'from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Set-AccessPackagePolicy','Set-AccessPackage','Get-ConditionalAccessPolicy', 'Get-ConditionalAccessPolicyFile', 'ConvertFrom-AgreementDisplayNametoGuid', 'ConvertFrom-AgreementGuidToDisplayName', 'ConvertFrom-ApplicationDisplayNameToGUID', 'ConvertFrom-ApplicationGUIDtoDisplayName', 'ConvertFrom-GroupDisplayNameToGUID', 'ConvertFrom-GroupGUIDToDisplayName ', 'ConvertFrom-LocationDisplayNametoGUID', 'ConvertFrom-LocationGUIDtoDisplayName', 'ConvertFrom-RoleDisplayNametoGUID', 'ConvertFrom-RoleGUIDtoDisplayName', 'ConvertFrom-UserDisplayNameToGUID', 'ConvertFrom-UserGUIDToDisplayName')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}

