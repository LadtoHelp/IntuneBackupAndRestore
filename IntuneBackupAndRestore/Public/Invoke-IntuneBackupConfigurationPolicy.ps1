function Invoke-IntuneBackupConfigurationPolicy {
    <#
    .SYNOPSIS
    Backup Intune Settings Catalog Policies
    
    .DESCRIPTION
    Backup Intune Settings Catalog Policies as JSON files per Settings Catalog Policy to the specified Path.
    
    .PARAMETER Path
    Path to store backup files

    .PARAMETER DateFrom
    Policies created after this date
    
    .EXAMPLE
    Invoke-IntuneBackupConfigurationPolicy -Path "C:\temp"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet("v1.0", "Beta")]
        [string]$ApiVersion = "Beta",
        [datetime]$DateFrom,
        $DateTo
    )

    # Set the Microsoft Graph API endpoint
    if (-not ((Get-MSGraphEnvironment).SchemaVersion -eq $apiVersion)) {
        Update-MSGraphEnvironment -SchemaVersion $apiVersion -Quiet
        Connect-MSGraph -ForceNonInteractive -Quiet
    }

    # Create folder if not exists
    if (-not (Test-Path "$Path\Settings Catalog")) {
        $null = New-Item -Path "$Path\Settings Catalog" -ItemType Directory
    }

    # Get all Setting Catalogs Policies
    $configurationPolicies = Invoke-MSGraphRequest -HttpMethod GET -Url "deviceManagement/configurationPolicies" | Get-MSGraphAllPages
        if ($DateFrom) {
            "filtering by date"
            $configurationPolicies = $configurationPolicies | ? {$_.createddatetime -gt $DateFrom}
        }


    foreach ($configurationPolicy in $configurationPolicies) {
        $configurationPolicy | Add-Member -MemberType NoteProperty -Name 'settings' -Value @() -Force
        $settings = Invoke-MSGraphRequest -HttpMethod GET -Url "deviceManagement/configurationPolicies/$($configurationPolicy.id)/settings" | Get-MSGraphAllPages

        if ($settings -isnot [System.Array]) {
            $configurationPolicy.Settings = @($settings)
        } else {
            $configurationPolicy.Settings = $settings
        }
        
        $fileName = ($configurationPolicy.name).Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        $configurationPolicy | ConvertTo-Json -Depth 100 | Out-File -LiteralPath "$path\Settings Catalog\$fileName.json"

        [PSCustomObject]@{
            "Action" = "Backup"
            "Type"   = "Settings Catalog"
            "Name"   = $configurationPolicy.name
            "Path"   = "Settings Catalog\$fileName.json"
        }
    }
}
