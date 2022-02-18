<#
.SYNOPSIS
Downloads a Manufacturer Driver Pack by selection using Out-Gridview to an OSDCloud USB

.DESCRIPTION
Downloads a Manufacturer Driver Pack by selection using Out-Gridview to an OSDCloud USB

.PARAMETER Manufacturer
Computer Manufacturer of the Driver Pack

.LINK
https://www.osdcloud.com
#>
function Update-OSDCloudOfflineUSB {
    [CmdletBinding()]
    param (
        [ValidateSet('*','ThisPC','Dell','HP','Lenovo','Microsoft')]
        [System.String[]]$DriverPack,

        [ValidateSet(
            'Windows 11 21H2',
            'Windows 10 21H2',
            'Windows 10 21H1',
            'Windows 10 20H2',
            'Windows 10 2004',
            'Windows 10 1909',
            'Windows 10 1903',
            'Windows 10 1809'
            )]
        [System.String]$OS,

        [ValidateSet('Retail','Volume')]
        [System.String]$OSLicense,

        [ValidateSet (
            'ar-sa','bg-bg','cs-cz','da-dk','de-de','el-gr',
            'en-gb','en-us','es-es','es-mx','et-ee','fi-fi',
            'fr-ca','fr-fr','he-il','hr-hr','hu-hu','it-it',
            'ja-jp','ko-kr','lt-lt','lv-lv','nb-no','nl-nl',
            'pl-pl','pt-br','pt-pt','ro-ro','ru-ru','sk-sk',
            'sl-si','sr-latn-rs','sv-se','th-th','tr-tr',
            'uk-ua','zh-cn','zh-tw'
        )]
        [System.String]$OSLanguage
    )
    #=================================================
    #	Block
    #=================================================
    Block-PowerShellVersionLt5
    Block-NoCurl
    Block-WinPE
    #=================================================
    #	Initialize
    #=================================================
    Write-Host -ForegroundColor DarkGray "========================================================================="
    $UsbVolumes = Get-Volume.usb
    #=================================================
    #	USB Volumes
    #   e9ae9fce-f699-4300-8276-3cdf8a9cf675
    #=================================================
    if ($UsbVolumes) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) USB volumes found"
    }
    else {
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Unable to find any USB volumes"
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) You may need to run New-OSDCloudUSB first"
        Get-Help New-OSDCloudUSB -Examples
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Break
    }
    #=================================================
    #   Header
    #=================================================
    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) OSDCloud content can be saved to an 8GB+ NTFS USB Volume"
    #=================================================
    #   OSDCloudVolumes
    #=================================================
    $OSDCloudVolumes = Get-Volume.usb | Where-Object {$_.FileSystem -eq 'NTFS'} | Where-Object {$_.SizeGB -ge 8} | Sort-Object DriveLetter -Descending
    
    if (-NOT ($OSDCloudVolumes)) {
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Unfortunately, I don't see any USB volumes that will work"
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Break
    }
    
    if (($OSDCloudVolumes).Count -gt 1) {
        Write-Host -ForegroundColor Yellow "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Select one or more USB Drives to update in the PowerShell GridView window"
        $OSDCloudVolumes = $OSDCloudVolumes | Out-GridView -Title 'Select an OSDCloud USB volume and press OK' -PassThru -OutputMode Single
    }

    if (-not ($OSDCloudVolumes)) {
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) You must select at lease one OSDCloud USB volume"
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Break
    }
    #=================================================
    #   OSDCloud OS
    #=================================================
    if ($OS -or $OSLicense -or $OSLanguage) {
        $OSDownloadPath = "$($OSDCloudVolumes.DriveLetter):\OSDCloud\OS"

        $OSDCloudSavedOS = $null
        if (Test-Path $OSDownloadPath) {
            $OSDCloudSavedOS = Get-ChildItem -Path $OSDownloadPath *.esd -Recurse -File | Select-Object -ExpandProperty Name
        }
        $OperatingSystems = Get-WSUSXML -Catalog FeatureUpdate -UpdateArch 'x64'
    
        if ($OS) {
            $OperatingSystems = $OperatingSystems | Where-Object {$_.Catalog -cmatch $OS}
        }
        if ($OSLicense -eq 'Retail') {
            $OperatingSystems = $OperatingSystems | Where-Object {$_.Title -match 'consumer'}
        }
        if ($OSLicense -eq 'Volume') {
            $OperatingSystems = $OperatingSystems | Where-Object {$_.Title -match 'business'}
        }
        if ($OSLanguage){
            $OperatingSystems = $OperatingSystems | Where-Object {$_.Title -match $OSLanguage}
        }
    
        if ($OperatingSystems) {
            $OperatingSystems = $OperatingSystems | Sort-Object Title

            foreach ($Item in $OperatingSystems) {
                $Item.Catalog = $Item.Catalog -replace 'FeatureUpdate ',''
                if ($OSDCloudSavedOS) {
                    if ($Item.FileName -in $OSDCloudSavedOS) {
                        $Item.OSDStatus = 'Downloaded'
                    }
                }
            }

            $OperatingSystems = $OperatingSystems | Select-Object -Property OSDVersion,OSDStatus,@{Name='OperatingSystem';Expression={($_.Catalog)}},Title,CreationDate,FileUri,FileName
    
            Write-Host -ForegroundColor Yellow "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Select one or more OSDCloud Operating Systems to download in PowerShell GridView"
            $OperatingSystems = $OperatingSystems | Sort-Object -Property OperatingSystem -Descending | Out-GridView -Title 'Select one or more OSDCloud Operating Systems to download and press OK' -PassThru
    
            foreach ($OperatingSystem in $OperatingSystems) {
                if ($OperatingSystem.OSDStatus -eq 'Downloaded') {
                    Get-ChildItem -Path $OSDownloadPath -Recurse -Include $OperatingSystem.FileName | Select-Object -ExpandProperty FullName
                }
                elseif (Test-WebConnection -Uri "$($OperatingSystem.FileUri)") {
                    $OSDownloadChildPath = Join-Path $OSDownloadPath (($OperatingSystem.Catalog) -replace 'FeatureUpdate ','')
                    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Downloading OSDCloud Operating System to $OSDownloadChildPath"
                    $SaveWebFile = Save-WebFile -SourceUrl $OperatingSystem.FileUri -DestinationDirectory "$OSDownloadChildPath" -DestinationName $OperatingSystem.FileName
                    
                    if (Test-Path $SaveWebFile.FullName) {
                        Get-Item $SaveWebFile.FullName
                    }
                    else {
                        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Could not download the OSDCloud Operating System"
                    }
                }
                else {
                    Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Could not verify an Internet connection for the OSDCloud Operating System"
                }
            }
        }
        else {
            Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Unable to determine a suitable OSDCloud Operating System"
        }
    }
    else {
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor DarkGray "To save an OSDCloud Offline Operating System:"
        Write-Host -ForegroundColor DarkGray "Update-OSDCloudOfflineUSB -OS 'Windows 11 21H2'"
        Write-Host -ForegroundColor DarkGray "Update-OSDCloudOfflineUSB -OS 'Windows 10 21H2' -OSLicense Retail"
        Write-Host -ForegroundColor DarkGray "Update-OSDCloudOfflineUSB -OS 'Windows 10 21H1' -OSLicense Volume -OSLanguage en-us"
    }
    #=================================================
    #   OSDCloud DriverPack
    #=================================================
    if ($DriverPack) {
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) DriverPacks will require up to 2GB each"
        $DriverPackDownloadPath = "$($OSDCloudVolumes.DriveLetter):\OSDCloud\DriverPacks"

        $OSDCloudSavedDriverPacks = $null
        if (Test-Path $DriverPackDownloadPath) {
            $OSDCloudSavedDriverPacks = Get-ChildItem -Path $DriverPackDownloadPath *.* -Recurse -File | Select-Object -ExpandProperty Name
        }

        if ($DriverPack -contains '*') {
            $DriverPack = 'Dell','HP','Lenovo','Microsoft'
        }

        if ($DriverPack -contains 'ThisPC') {
            $Manufacturer = Get-MyComputerManufacturer -Brief
            Save-MyDriverPack -DownloadPath "$DriverPackDownloadPath\$Manufacturer"
        }
    
        if ($DriverPack -contains 'Dell') {
            Get-DellDriverPack -DownloadPath "$DriverPackDownloadPath\Dell"
        }
        if ($DriverPack -contains 'HP') {
            Get-HPDriverPack -DownloadPath "$DriverPackDownloadPath\HP"
        }
        if ($DriverPack -contains 'Lenovo') {
            Get-LenovoDriverPack -DownloadPath "$DriverPackDownloadPath\Lenovo"
        }
        if ($DriverPack -contains 'Microsoft') {
            Get-MicrosoftDriverPack -DownloadPath "$DriverPackDownloadPath\Microsoft"
        }
    }
    else {
        Write-Host -ForegroundColor DarkGray "========================================================================="
        Write-Host -ForegroundColor DarkGray "To save an OSDCloud Offline Driver Pack:"
        Write-Host -ForegroundColor DarkGray "Update-OSDCloudOfflineUSB -DriverPack *"
        Write-Host -ForegroundColor DarkGray "Update-OSDCloudOfflineUSB -DriverPack ThisPC"
        Write-Host -ForegroundColor DarkGray "Update-OSDCloudOfflineUSB -DriverPack Dell"
        Write-Host -ForegroundColor DarkGray "Update-OSDCloudOfflineUSB -DriverPack Dell,HP,Lenovo,Microsoft"
        Write-Host -ForegroundColor DarkGray "========================================================================="
    }
    #=================================================
    #   PowerShell
    #=================================================
    $PowerShellPath = "$($OSDCloudVolumes.DriveLetter):\OSDCloud\PowerShell"
    if (-not (Test-Path "$PowerShellPath")) {
        $null = New-Item -Path "$PowerShellPath" -ItemType Directory -Force -ErrorAction Ignore
    }
    if (-not (Test-Path "$PowerShellPath\Offline\Modules")) {
        $null = New-Item -Path "$PowerShellPath\Offline\Modules" -ItemType Directory -Force -ErrorAction Ignore
    }
    if (-not (Test-Path "$PowerShellPath\Offline\Scripts")) {
        $null = New-Item -Path "$PowerShellPath\Offline\Scripts" -ItemType Directory -Force -ErrorAction Ignore
    }
    if (-not (Test-Path "$PowerShellPath\Required\Modules")) {
        $null = New-Item -Path "$PowerShellPath\Required\Modules" -ItemType Directory -Force -ErrorAction Ignore
    }
    if (-not (Test-Path "$PowerShellPath\Required\Scripts")) {
        $null = New-Item -Path "$PowerShellPath\Required\Scripts" -ItemType Directory -Force -ErrorAction Ignore
    }
    #=================================================
    #   Online
    #=================================================
    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Updating OSD and WindowsAutoPilotIntune PowerShell Modules at $PowerShellPath"

    try {
        Save-Module OSD -Path "$PowerShellPath\Offline\Modules" -ErrorAction Stop
    }
    catch {
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) There were some issues updating the OSD PowerShell Module at $PowerShellPath\Offline\Modules"
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Make sure you have an Internet connection and can access powershellgallery.com"
    }

    try {
        Save-Module WindowsAutoPilotIntune -Path "$PowerShellPath\Offline\Modules" -ErrorAction Stop
    }
    catch {
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) There were some issues updating the WindowsAutoPilotIntune PowerShell Module at $PowerShellPath\Offline\Modules"
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Make sure you have an Internet connection and can access powershellgallery.com"
    }

    try {
        Save-Script -Name Get-WindowsAutopilotInfo -Path "$PowerShellPath\Offline\Scripts" -ErrorAction Stop
    }
    catch {
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) There were some issues updating the Get-WindowsAutopilotInfo PowerShell Script at $PowerShellPath\Offline\Scripts"
        Write-Warning "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Make sure you have an Internet connection and can access powershellgallery.com"
    }
    #=================================================
    #   Complete
    #=================================================
    Write-Host -ForegroundColor Cyan "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Update-OSDCloudOfflineUSB is complete"
    Write-Host -ForegroundColor DarkGray "========================================================================="
    #=================================================
}