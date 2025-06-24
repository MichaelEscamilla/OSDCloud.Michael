function step-install-downloadwindowsimage {
    [CmdletBinding()]
    param (
        $OperatingSystemObject = $global:OSDCloudWorkflowInvoke.OperatingSystemObject
    )
    #=================================================
    # Start the step
    $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] Start"
    Write-Debug -Message $Message; Write-Verbose -Message $Message

    # Get the configuration of the step
    $Step = $global:OSDCloudWorkflowCurrentStep
    #=================================================
    # Do we have a URL to download the Windows Image from?
    if (-not ($OperatingSystemObject.Url)) {
        Write-Warning "[$(Get-Date -format G)] OSDCloud failed to download the WindowsImage from the Internet"
        Write-Warning 'Press Ctrl+C to cancel OSDCloud'
        Start-Sleep -Seconds 86400
        exit
    }
    #=================================================
    # Create OS Directory
    $ItemParams = @{
        ErrorAction = 'SilentlyContinue'
        Force       = $true
        ItemType    = 'Directory'
        Path        = 'C:\OSDCloud\OS'
    }
    if (!(Test-Path $ItemParams.Path -ErrorAction SilentlyContinue)) {
        New-Item @ItemParams | Out-Null
    }
    #=================================================
    # Check if the file already exists on another drive
    $FileName = Split-Path $OperatingSystemObject.Url -Leaf
    $OfflineOSFile = Find-OSDCloudFile -Name $FileName -Path '\OSDCloud\OS\' | Sort-Object FullName | Where-Object { $_.Length -gt 3GB }
    if ($OfflineOSFile) {
        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Offline OS Image Found: $($OfflineOSFile.FullName)"
        $FileInfo = $OfflineOSFile
    }
    #==================================================
    # Is there a USB drive available?
    $USBDrive = Get-USBVolume | Where-Object { ($_.FileSystemLabel -match "OSDCloud|USB-DATA") } | Where-Object { $_.SizeGB -ge 16 } | Where-Object { $_.SizeRemainingGB -ge 10 } | Select-Object -First 1

    if ($USBDrive) {
        $DownloadPath = "$($USBDrive.DriveLetter):\OSDCloud\OS\$($OperatingSystemObject.OperatingSystem) $($OperatingSystemObject.ReleaseID)"
        $FileName = Split-Path $OperatingSystemObject.Url -Leaf

        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Url: $($OperatingSystemObject.Url)"
        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] DownloadPath: $DownloadPath"
        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] FileName: $FileName"

        # Check if we already have the file available
        if ($FileInfo) {
            Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Copying Offline OS to USB Drive: $($USBDrive.DriveLetter):\OSDCloud\OS\$($FileName)"
            # Copy the file to the USB drive
            $null = Copy-Item -Path $FileInfo.FullName -Destination "$DownloadPath" -Force
            $OfflineUSBFile = $FileInfo
        }
        else {
            # Download the file
            $OfflineUSBFile = Save-WebFile -SourceUrl $OperatingSystemObject.Url -DestinationDirectory "$DownloadPath" -DestinationName $FileName
        }

        if ($OfflineUSBFile) {
            Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Copy Offline OS to C:\OSDCloud\OS\$($OfflineUSBFile.Name)"
            $null = Copy-Item -Path $OfflineUSBFile.FullName -Destination 'C:\OSDCloud\OS' -Force
            $FileInfo = Get-Item "C:\OSDCloud\OS\$($OfflineUSBFile.Name)"
        }
    }
    #=================================================
    # Download the file from the Internet
    if (-not ($FileInfo)) {
        # $SaveWebFile is a FileInfo Object, not a path
        $SaveWebFile = Save-WebFile -SourceUrl $OperatingSystemObject.Url -DestinationDirectory 'C:\OSDCloud\OS' -ErrorAction Stop
        $FileInfo = $SaveWebFile
    }
    #=================================================
    # Do we have FileInfo for the downloaded file?
    if (-not ($FileInfo)) {
        Write-Warning "[$(Get-Date -format G)] Unable to download the WindowsImage from the Internet."
        Write-Warning 'Press Ctrl+C to cancel OSDCloud'
        Start-Sleep -Seconds 86400
        exit
    }
    #=================================================
    # Store this as a FileInfo Object
    $global:OSDCloudWorkflowInvoke.FileInfoWindowsImage = $FileInfo
    $global:OSDCloudWorkflowInvoke.WindowsImagePath = $global:OSDCloudWorkflowInvoke.FileInfoWindowsImage.FullName
    Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] WindowsImagePath:  $($global:OSDCloudWorkflowInvoke.WindowsImagePath)"
    #=================================================
    # Check the File Hash
    if ($OperatingSystemObject.Sha1) {
        $FileHash = (Get-FileHash -Path $FileInfo.FullName -Algorithm SHA1).Hash

        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Microsoft Verified ESD SHA1: $($OperatingSystemObject.Sha1)"
        Write-Host -ForegroundColor DarkGray "[$(Get-Date -format G)] Downloaded ESD SHA1: $FileHash"

        if ($OperatingSystemObject.Sha1 -ne $FileHash) {
            Write-Warning "[$(Get-Date -format G)] Unable to deploy this Operating System."
            Write-Warning "[$(Get-Date -format G)] Downloaded ESD SHA1 does not match the verified Microsoft ESD SHA1."
            Write-Warning 'Press Ctrl+C to cancel OSDCloud'
            Start-Sleep -Seconds 86400
        }
        else {
            Write-Host -ForegroundColor Green "[$(Get-Date -format G)] Downloaded ESD SHA1 matches the verified Microsoft ESD SHA1. OK."
        }
    }
    #=================================================
    # End the function
    $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] End"
    Write-Verbose -Message $Message; Write-Debug -Message $Message
    #=================================================
}