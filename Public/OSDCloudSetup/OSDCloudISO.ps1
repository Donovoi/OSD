function New-OSDCloudISO {
    <#
    .SYNOPSIS
    Creates an .iso file in the OSDCloud Workspace.  ADK is required

    .DESCRIPTION
    Creates an .iso file in the OSDCloud Workspace.  ADK is required

    .EXAMPLE
    New-OSDCloudISO

    .EXAMPLE
    New-OSDCloudISO -WorkspacePath C:\OSDCloud

    .LINK
    https://www.osdcloud.com/setup/osdcloud-iso
    #>

    [CmdletBinding()]
    param (
        #Path to the OSDCloud Workspace containing the Media directory
        #This parameter is not necessary if Get-OSDCloudWorkspace can get a return
        [Parameter(Position=0,ValueFromPipelineByPropertyName)]
        [System.String]$WorkspacePath
    )
    #=================================================
    #	Block
    #=================================================
    Block-NoCurl
    Block-PowerShellVersionLt5
    Block-StandardUser
    Block-WindowsVersionNe10
    Block-WinPE
    #=================================================
    #	Initialize
    #=================================================
    $isoFileName = 'OSDCloud.iso'
    $isoLabel = 'OSDCloud'
    $ErrorActionPreference = 'Stop'
    #=================================================
    #	WorkspacePath
    #=================================================
    if ($PSBoundParameters.ContainsKey('WorkspacePath')) {
        Set-OSDCloudWorkspace -WorkspacePath $WorkspacePath -ErrorAction Stop | Out-Null
    }
    $WorkspacePath = Get-OSDCloudWorkspace -ErrorAction Stop

    if (-NOT ($WorkspacePath)) {
        Write-Warning "[$(Get-Date -format G)] Unable to find an OSDCloud Workspace at $WorkspacePath"
        Break
    }

    if (-NOT (Test-Path $WorkspacePath)) {
        Write-Warning "[$(Get-Date -format G)] Unable to find an OSDCloud Workspace at $WorkspacePath"
        Break
    }

    if (-NOT (Test-Path "$WorkspacePath\Media\sources\boot.wim")) {
        Write-Warning "[$(Get-Date -format G)] Unable to find an OSDCloud WinPE at $WorkspacePath\Media\sources\boot.wim"
        Break
    }

    #region OSDeploy Compatibility
    if (Test-Path "$WorkspacePath\OSDeploy.iso") {
        $isoFileName = 'OSDeploy.iso'
        $isoLabel = 'OSDeploy'
    }
    #endregion
    #=================================================
    #   Create ISO
    #=================================================
    $NewADKiso = New-WindowsAdkISO -MediaPath "$WorkspacePath\Media" -isoFileName $isoFileName -isoLabel $isoLabel
    #=================================================
    #   Complete
    #=================================================
    #Write-Host -ForegroundColor Cyan "[$(Get-Date -format G)] New-OSDCloudISO is complete"
    #=================================================
}