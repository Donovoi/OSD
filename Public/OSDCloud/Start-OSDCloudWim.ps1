<#
.SYNOPSIS
Starts the OSDCloud Build Process using a WIM File on USB

.DESCRIPTION
Starts the OSDCloud Build Process using a WIM File on USB

.PARAMETER Screenshot
Captures screenshots during OSDCloud

.LINK
https://osdcloud.osdeploy.com/

.NOTES
#>
function Start-OSDCloudWim {
    [CmdletBinding()]
    param (
        [switch]$Screenshot,

        [switch]$SkipAutopilot,

        [switch]$ZTI,

        [string]$Manufacturer = (Get-MyComputerManufacturer -Brief),
        [string]$Product = (Get-MyComputerProduct)
    )
    #=======================================================================
    #	Start the Clock
    #=======================================================================
    $OSDCloudStartTime = Get-Date
    #=======================================================================
    #	Block
    #=======================================================================
    Block-StandardUser
    Block-PowerShellVersionLt5
    Block-NoCurl
    #=======================================================================
    #	-Screenshot
    #=======================================================================
    if ($PSBoundParameters.ContainsKey('Screenshot')) {
        $OSDCloudScreenshot = "$env:TEMP\ScreenPNG"
        Start-ScreenPNGProcess -Directory $OSDCloudScreenshot
    }
    else {
        $OSDCloudScreenshot = $null
    }
    #=======================================================================
    #   Header
    #=======================================================================
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Green "Start-OSDCloudWim"
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Cyan "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) $($MyInvocation.MyCommand.Name)" -NoNewline
    Write-Host -ForegroundColor Cyan " | Manufacturer: $Manufacturer | Product: $Product"
    #=======================================================================
    #	-ZTI
    #=======================================================================
    if ($ZTI) {
        $GetDisk = Get-Disk.fixed | Where-Object {$_.IsBoot -eq $false} | Sort-Object Number

        if (($GetDisk | Measure-Object).Count -lt 2) {
            Write-Host -ForegroundColor DarkGray "========================================================================="
            Write-Warning "This Warning is displayed when using the -ZTI parameter"
            Write-Warning "OSDisk will be cleaned automatically without confirmation"
            Write-Warning "Press CTRL + C to cancel"
            $GetDisk | Select-Object -Property Number, BusType, MediaType,`
            FriendlyName, PartitionStyle, NumberOfPartitions,`
            @{Name='SizeGB';Expression={[int]($_.Size / 1000000000)}} | Format-Table
    
            Write-Warning "OSDCloud will continue in 5 seconds"
            Start-Sleep -Seconds 5
        }
        else {
            Write-Host -ForegroundColor DarkGray "========================================================================="
            Write-Warning "More than 1 Fixed Disk is present"
            Write-Warning "Disks will not be cleaned automatically"
            Start-Sleep -Seconds 5
        }
    }
    #=======================================================================
    #	Battery
    #=======================================================================
    if (Get-OSDGather -Property IsOnBattery) {
        Write-Warning "This computer is currently running on Battery"
    }
    #=======================================================================
    #	Test Web Connection
    #=======================================================================
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Cyan "Test-WebConnection"
    Write-Host -ForegroundColor DarkGray "google.com"

    if (Test-WebConnection -Uri "google.com") {
        Write-Host -ForegroundColor Green "OK"
    }
    else {
        Write-Host -ForegroundColor Red " FAILED"
        Write-Warning "Could not validate an Internet connection"
        Write-Warning "OSDCloud will continue, but there may be issues if this can't be resolved"
    }
    #=======================================================================
    #	WIM File
    #=======================================================================
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Cyan "Custom Windows Image on USB"
    $ImageFileOffline = Select-OSDCloudFile.wim

    if ($ImageFileOffline) {
        #$OSDCloudImageFileName = ($ImageFile).Name
        #$Global:OSDImageParent = Split-Path -Path ($ImageFile).Directory -Leaf
        #$ImageFileOffline = ($ImageFile).FullName
        #$Global:OSDImageHash = (Get-FileHash -Path $ImageFile.FullName -Algorithm SHA1).Hash

        $ImageIndex = Select-OSDCloudImageIndex -ImagePath $ImageFileOffline.FullName

        #Write-Host -ForegroundColor DarkGray "OSDCloudWimName: $Global:OSDCloudWimName"
        Write-Host -ForegroundColor DarkGray "ImageFileOffline: $($ImageFileOffline.FullName)"
        Write-Host -ForegroundColor DarkGray "ImageIndex: $ImageIndex"
        #Write-Host -ForegroundColor DarkGray "OSDImageParent: $Global:OSDImageParent"
    }
    else {
        $ImageFileOffline = $null
        $ImageIndex = $null
        #$Global:OSDImageParent = $null
        #$Global:OSDCloudWimFullName = $null
        Write-Warning "Custom Windows Image on USB was not found"
        Break
    }
    #=======================================================================
    #	Start-OSDCloud Get-MyDriverPack
    #=======================================================================
    if ($Product -ne 'None') {
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor Cyan "Get-MyDriverPack"
        
        if ($PSBoundParameters.ContainsKey('Manufacturer')) {
            $GetMyDriverPack = Get-MyDriverPack -Manufacturer $Manufacturer -Product $Product
        }
        else {
            $GetMyDriverPack = Get-MyDriverPack -Product $Product
        }
    
        if ($GetMyDriverPack) {
            Write-Host -ForegroundColor DarkGray "Name: $($GetMyDriverPack.Name)"
            Write-Host -ForegroundColor DarkGray "Product: $($GetMyDriverPack.Product)"
    
            $DriverPackOffline = Find-OSDCloudOfflineFile -Name $GetMyDriverPack.FileName | Select-Object -First 1
            if ($DriverPackOffline) {
                Write-Host -ForegroundColor Green "OK"
                Write-Host -ForegroundColor DarkGray "$($DriverPackOffline.FullName)"
            }
            elseif (Test-WebConnection -Uri $GetMyDriverPack.DriverPackUrl) {
                Write-Host -ForegroundColor Yellow "Download"
                Write-Host -ForegroundColor Yellow "$($GetMyDriverPack.DriverPackUrl)"
            }
            else {
                Write-Warning "Could not verify an Internet connection for the Dell Driver Pack"
                Write-Warning "OSDCloud will continue, but there may be issues"
            }
        }
        else {
            Write-Warning "Unable to determine a suitable Driver Pack for this Computer Model"
        }
    }
    #=======================================================================
    #	Get-MyDellBios
    #=======================================================================
<#     if ($Manufacturer -eq 'Dell') {
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor Cyan "Get-MyDellBios"

        $GetMyDellBios = Get-MyDellBios
        if ($GetMyDellBios) {
            Write-Host -ForegroundColor DarkGray "$($GetMyDellBios.Name)"
            Write-Host -ForegroundColor DarkGray "$($GetMyDellBios.ReleaseDate)"

            $GetOSDCloudOfflineFile = Find-OSDCloudOfflineFile -Name $GetMyDellBios.FileName | Select-Object -First 1

            if ($OSDCloudOfflineBios) {
                Write-Host -ForegroundColor Green "OK"
                Write-Host -ForegroundColor DarkGray "$($OSDCloudOfflineBios.FullName)"
            }
            elseif (Test-MyDellBiosWebConnection) {
                Write-Host -ForegroundColor Yellow "Download"
                Write-Host -ForegroundColor Yellow "$($GetMyDellBios.Url)"
            }
            else {
                Write-Warning "Could not verify an Internet connection for the Dell Bios Update"
                Write-Warning "OSDCloud will continue, but there may be issues"
            }

            $OSDCloudOfflineFlash64W = Find-OSDCloudOfflineFile -Name 'Flash64W.exe' | Select-Object -First 1
            if ($OSDCloudOfflineFlash64W) {
                Write-Host -ForegroundColor DarkGray "$($OSDCloudOfflineFlash64W.FullName)"
            }
            elseif (Test-MyDellBiosWebConnection) {
                Write-Host -ForegroundColor Yellow "$($GetMyDellBios.Flash64W)"
            }
            else {
                Write-Warning "Could not verify an Internet connection for the Dell Flash64W"
                Write-Warning "OSDCloud will continue, but there may be issues"
            }
        }
        else {
            Write-Warning "Unable to determine a suitable BIOS update for this Computer Model"
            Write-Warning "OSDCloud will continue, but there may be issues"
        }
    } #>
    #=======================================================================
    #	List Autopilot Profiles
    #=======================================================================
<#     if (!($SkipAutopilot -eq $true)) {
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor Cyan "OSDCloud Autopilot"
        
        $FindOSDCloudFile = Find-OSDCloudFile -Name "*.json" -Path '\OSDCloud\Autopilot\Profiles\' | Sort-Object FullName
        $FindOSDCloudFile = $FindOSDCloudFile | Where-Object {$_.FullName -notlike "C*"}
    
        if ($FindOSDCloudFile) {
            Write-Host -ForegroundColor Green "OK"
            if ($ZTI) {
                Write-Warning "-SkipAutopilot parameter can be used to skip Autopilot Configuration"
                Write-Warning "-ZTI automatically selects the first Autopilot Profile listed below"
                Write-Warning "Rename your Autopilot Configuration Files so your default is the first Selection"
            }
            foreach ($Item in $FindOSDCloudFile) {
                Write-Host -ForegroundColor DarkGray "$($Item.FullName)"
            }
        } else {
            Write-Warning "No Autopilot Profiles were found in any PSDrive"
            Write-Warning "Autopilot Profiles must be located in a <PSDrive>:\OSDCloud\Autopilot\Profiles directory"
        }
    } #>
    #=======================================================================
    #	Global Variables
    #=======================================================================
    #Autopilot
    $Global:OSDCloudSkipAutopilot = $SkipAutopilot
    #Hardware
    $Global:OSDCloudManufacturer = $Manufacturer
    $Global:OSDCloudProduct = $Product
    #DriverPack
    $Global:OSDCloudDriverPack = $GetMyDriverPack
    $Global:OSDCloudDriverPackFileName = $GetMyDriverPack.FileName
    $Global:OSDCloudDriverPackUrl = $GetMyDriverPack.DriverPackUrl
    $Global:OSDCloudDriverPackOffline = $DriverPackOffline
    #OS
    $Global:OSDCloudOSBuild = $OSBuild
    $Global:OSDCloudOSEdition = $OSEdition
    $Global:OSDCloudOSEditionId = $OSEditionId
    $Global:OSDCloudOSImageIndex = $ImageIndex
    $Global:OSDCloudOSLanguage = $OSLanguage
    $Global:OSDCloudOSLicense = $OSLicense
    #Image
    $Global:OSDCloudImageFileName = $GetFeatureUpdate.FileName
    $Global:OSDCloudImageFileHash = $GetFeatureUpdate.Hash
    $Global:OSDCloudImageFileOffline = $ImageFileOffline
    $Global:OSDCloudImageFileTitle = $GetFeatureUpdate.Title
    $Global:OSDCloudImageFileUri = $GetFeatureUpdate.FileUri
    #Screenshot
    $Global:OSDCloudScreenshot = $OSDCloudScreenshot
    #Start Time
    $Global:OSDCloudStartTime = $OSDCloudStartTime
    #ZTI
    if ($PSBoundParameters.ContainsKey('ZTI')) {
        $Global:OSDCloudZTI = $true
        $Global:OSDCloudSkipODT = $true
    }
    else {
        $Global:OSDCloudZTI = $false
        $Global:OSDCloudSkipODT = $false
    }
    #=======================================================================
    #   Deploy-OSDCloud.ps1
    #=======================================================================
    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor Green "Starting in 5 seconds..."
    Write-Host -ForegroundColor Green "$($MyInvocation.MyCommand.Module.ModuleBase)\OSDCloud\Deploy-OSDCloud.ps1"
    Start-Sleep -Seconds 5
    & "$($MyInvocation.MyCommand.Module.ModuleBase)\OSDCloud\Deploy-OSDCloud.ps1"
    #=======================================================================
}