# ToolHub.ps1 - Portable Tool Hub for Remote Support
# Downloads, runs, and cleans up tools without leaving traces

function Start-ToolHub {
    function Get-SystemArchitecture {
        <#
        .SYNOPSIS
        Detects if the system is 32-bit or 64-bit
        .DESCRIPTION
        Returns "x86" for 32-bit systems and "x64" for 64-bit systems
        #>
        if ([Environment]::Is64BitOperatingSystem) {
            return "x64"
        } else {
            return "x86"
        }
    }

    function Get-PortableToolFromZip {
        <#
        .SYNOPSIS
        Downloads, extracts, runs, and cleans up a portable tool from a ZIP file
        .PARAMETER ToolName
        The name of the tool for display purposes
        .PARAMETER DownloadUrl
        The URL to download the ZIP file from
        .PARAMETER ExecutableName
        The name of the executable file to run after extraction
        .PARAMETER ExtractToSubfolder
        Whether to extract to a subfolder (default: true)
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$ToolName,

            [Parameter(Mandatory)]
            [string]$DownloadUrl,

            [Parameter(Mandatory)]
            [string]$ExecutableName,

            [bool]$ExtractToSubfolder = $true
        )

        # Create a unique temporary directory for our tool
        $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        Write-Host "Created temporary directory: $tempDir" -ForegroundColor Green

        # Use a try...finally block to ensure cleanup always happens
        try {
            $zipFile = Join-Path $tempDir "tool.zip"

            # 1. Download
            Write-Host "Downloading $ToolName from $DownloadUrl..." -ForegroundColor Yellow
            try {
                Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipFile -UseBasicParsing
                Write-Host "Download complete." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to download $ToolName`: $($_.Exception.Message)"
                return
            }

            # 2. Extract
            Write-Host "Extracting $zipFile..." -ForegroundColor Yellow
            try {
                if ($ExtractToSubfolder) {
                    Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
                } else {
                    # Extract to a subfolder to avoid conflicts
                    $extractDir = Join-Path $tempDir "extracted"
                    New-Item -ItemType Directory -Path $extractDir | Out-Null
                    Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force
                }
                Write-Host "Extraction complete." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to extract $ToolName`: $($_.Exception.Message)"
                return
            }

            # Find the executable, even if it's in a subfolder
            $searchPath = if ($ExtractToSubfolder) { $tempDir } else { $extractDir }
            $exePath = Get-ChildItem -Path $searchPath -Filter $ExecutableName -Recurse | Select-Object -First 1
            
            if (-not $exePath) {
                Write-Error "Could not find executable '$ExecutableName' after extraction."
                Write-Host "Available files in extraction directory:" -ForegroundColor Yellow
                Get-ChildItem -Path $searchPath -Recurse | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
                return
            }
            
            # 3. Run and Wait
            Write-Host "Running $ToolName. Please close the application when you are finished." -ForegroundColor Cyan
            Write-Host "Executable path: $($exePath.FullName)" -ForegroundColor Gray
            Start-Process -FilePath $exePath.FullName -Wait
            Write-Host "$ToolName has been closed." -ForegroundColor Green
        }
        finally {
            # 4. Clean up
            Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
            if (Test-Path $tempDir) {
                try {
                    # Wait a moment to ensure the process is fully closed
                    Start-Sleep -Seconds 1
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction Stop
                    Write-Host "Cleanup complete." -ForegroundColor Green
                }
                catch {
                    Write-Warning "Could not completely clean up temporary files. You may need to manually delete: $tempDir"
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }

    function Get-PortableExe {
        <#
        .SYNOPSIS
        Downloads, runs, and cleans up a portable executable file
        .PARAMETER ToolName
        The name of the tool for display purposes
        .PARAMETER DownloadUrl
        The URL to download the EXE file from
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$ToolName,

            [Parameter(Mandatory)]
            [string]$DownloadUrl
        )

        # Create a unique temporary directory for our tool
        $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        Write-Host "Created temporary directory: $tempDir" -ForegroundColor Green

        # Use a try...finally block to ensure cleanup always happens
        try {
            $exeFile = Join-Path $tempDir "$ToolName.exe"

            # 1. Download
            Write-Host "Downloading $ToolName from $DownloadUrl..." -ForegroundColor Yellow
            try {
                Invoke-WebRequest -Uri $DownloadUrl -OutFile $exeFile -UseBasicParsing
                Write-Host "Download complete." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to download $ToolName`: $($_.Exception.Message)"
                return
            }

            # 2. Run and Wait
            Write-Host "Running $ToolName. Please close the application when you are finished." -ForegroundColor Cyan
            Write-Host "Executable path: $exeFile" -ForegroundColor Gray
            Start-Process -FilePath $exeFile -Wait
            Write-Host "$ToolName has been closed." -ForegroundColor Green
        }
        finally {
            # 3. Clean up
            Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
            if (Test-Path $tempDir) {
                try {
                    # Wait a moment to ensure the process is fully closed
                    Start-Sleep -Seconds 1
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction Stop
                    Write-Host "Cleanup complete." -ForegroundColor Green
                }
                catch {
                    Write-Warning "Could not completely clean up temporary files. You may need to manually delete: $tempDir"
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }

    function Show-ToolMenu {
        Clear-Host
        Write-Host "  PORTABLE TOOL HUB" -ForegroundColor Cyan
        Write-Host "=====================" -ForegroundColor Cyan
        Write-Host "1.  Journal Trace" -ForegroundColor White
        Write-Host "2.  Last Activity Viewer" -ForegroundColor White
        Write-Host "3.  Everything Search" -ForegroundColor White
        Write-Host "4.  Win Prefetch Viewer (Auto-detect architecture)" -ForegroundColor White
        Write-Host "5.  Run All Tools (Sequentially)" -ForegroundColor Yellow
        Write-Host "6.  Clean All Temporary Files" -ForegroundColor Red
        Write-Host "Q.  Quit" -ForegroundColor Gray
        Write-Host
        Write-Host "System Architecture: $(Get-SystemArchitecture)" -ForegroundColor Magenta
        Write-Host
    }

    function Clean-AllTempFiles {
    <#
    .SYNOPSIS
    Cleans up all temporary files that might have been left behind
    #>
    Write-Host "Scanning for temporary tool files..." -ForegroundColor Yellow
    
    $tempDir = $env:TEMP
    $cleanedCount = 0
    $failedCount = 0
    $skippedCount = 0
    
    # System files that should never be deleted
    $systemFiles = @(
        'AppxProvider.dll',
        'WimProvider.dll',
        'wdscore.dll'
    )
    
    # Look for directories that might be from our tool hub
    Get-ChildItem -Path $tempDir -Directory | ForEach-Object {
        if ($_.Name -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            $dirPath = $_.FullName
            Write-Host "Checking directory: $($_.Name)" -ForegroundColor Gray
            
            # First, check if this directory contains any system files
            $hasSystemFiles = $false
            foreach ($file in $systemFiles) {
                if (Test-Path (Join-Path $dirPath $file)) {
                    $hasSystemFiles = $true
                    Write-Host "  Contains system file: $file" -ForegroundColor Yellow
                    break
                }
            }
            
            if ($hasSystemFiles) {
                Write-Host "  Skipping directory with system files: $($_.Name)" -ForegroundColor Yellow
                $skippedCount++
                return
            }
            
            try {
                # Get all files in the directory
                $items = Get-ChildItem -Path $dirPath -Recurse -Force -ErrorAction SilentlyContinue
                $canDelete = $true
                $lockedFiles = @()
                
                # Check each file
                foreach ($item in $items) {
                    if ($item.Extension -in @('.exe', '.dll')) {
                        try {
                            $fileStream = [System.IO.File]::Open($item.FullName, 'Open', 'Read', 'None')
                            $fileStream.Close()
                            $fileStream.Dispose()
                        }
                        catch {
                            $canDelete = $false
                            $lockedFiles += $item.Name
                        }
                    }
                }
                
                if ($canDelete) {
                    # Try to remove the directory
                    Remove-Item -Path $dirPath -Recurse -Force -ErrorAction Stop
                    Write-Host "  Cleaned: $($_.Name)" -ForegroundColor Green
                    $cleanedCount++
                } else {
                    Write-Host "  Skipped (files in use: $($lockedFiles -join ', '))" -ForegroundColor Yellow
                    $skippedCount++
                }
            }
            catch {
                Write-Host "  Failed to clean: $($_.Exception.Message)" -ForegroundColor Red
                $failedCount++
            }
        }
    }
        
            Write-Host
    Write-Host "Cleanup Summary:" -ForegroundColor Cyan
    if ($cleanedCount -gt 0) {
        Write-Host "  ✓ Successfully cleaned: $cleanedCount directories" -ForegroundColor Green
    }
    if ($skippedCount -gt 0) {
        Write-Host "  ! Skipped (system files or in use): $skippedCount directories" -ForegroundColor Yellow
    }
    if ($failedCount -gt 0) {
        Write-Host "  × Failed to clean: $failedCount directories" -ForegroundColor Red
    }
    if ($cleanedCount -eq 0 -and $skippedCount -eq 0 -and $failedCount -eq 0) {
        Write-Host "  No temporary tool directories found to clean." -ForegroundColor Cyan
    }
    Write-Host
    }

    # --- Main script logic ---
    Write-Host "ToolHub.ps1 - Portable Tool Hub for Remote Support" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host
    Write-Host "Credits:" -ForegroundColor Yellow
    Write-Host "  Concept & Design: " -NoNewline -ForegroundColor Gray
    Write-Host "Cellie" -ForegroundColor Magenta
    Write-Host "  Implementation: " -NoNewline -ForegroundColor Gray
    Write-Host "Mistral" -ForegroundColor Blue
    Write-Host

    do {
        Show-ToolMenu
        $selection = Read-Host "Please make a selection"

        switch ($selection) {
            '1' {
                # Journal Trace - Direct EXE download
                Get-PortableExe -ToolName "JournalTrace" -DownloadUrl "https://github.com/ponei/JournalTrace/releases/download/1.0/JournalTrace.exe"
                Read-Host "Press Enter to return to the menu..."
            }
            '2' {
                # Last Activity Viewer - ZIP download
                Get-PortableToolFromZip -ToolName "Last Activity Viewer" -DownloadUrl "https://www.nirsoft.net/utils/lastactivityview.zip" -ExecutableName "LastActivityView.exe"
                Read-Host "Press Enter to return to the menu..."
            }
            '3' {
                # Everything Search - ZIP download
                Get-PortableToolFromZip -ToolName "Everything Search" -DownloadUrl "https://www.voidtools.com/Everything-1.4.1.1028.x86.zip" -ExecutableName "Everything.exe"
                Read-Host "Press Enter to return to the menu..."
            }
            '4' {
                # Win Prefetch Viewer - Auto-detect architecture
                $arch = Get-SystemArchitecture
                Write-Host "Detected system architecture: $arch" -ForegroundColor Magenta
                
                if ($arch -eq "x64") {
                    $url = "https://www.nirsoft.net/utils/winprefetchview-x64.zip"
                } else {
                    $url = "https://www.nirsoft.net/utils/winprefetchview.zip"
                }
                
                Get-PortableToolFromZip -ToolName "Win Prefetch Viewer ($arch)" -DownloadUrl $url -ExecutableName "WinPrefetchView.exe"
                Read-Host "Press Enter to return to the menu..."
            }
            '5' {
                # Run all tools sequentially
                Write-Host "Running all tools sequentially..." -ForegroundColor Yellow
                Write-Host "You will be prompted to close each tool before the next one starts." -ForegroundColor Cyan
                Read-Host "Press Enter to continue..."
                
                # Journal Trace
                Get-PortableExe -ToolName "JournalTrace" -DownloadUrl "https://github.com/ponei/JournalTrace/releases/download/1.0/JournalTrace.exe"
                
                # Last Activity Viewer
                Get-PortableToolFromZip -ToolName "Last Activity Viewer" -DownloadUrl "https://www.nirsoft.net/utils/lastactivityview.zip" -ExecutableName "LastActivityView.exe"
                
                # Everything Search
                Get-PortableToolFromZip -ToolName "Everything Search" -DownloadUrl "https://www.voidtools.com/Everything-1.4.1.1028.x86.zip" -ExecutableName "Everything.exe"
                
                # Win Prefetch Viewer
                $arch = Get-SystemArchitecture
                if ($arch -eq "x64") {
                    $url = "https://www.nirsoft.net/utils/winprefetchview-x64.zip"
                } else {
                    $url = "https://www.nirsoft.net/utils/winprefetchview.zip"
                }
                Get-PortableToolFromZip -ToolName "Win Prefetch Viewer ($arch)" -DownloadUrl $url -ExecutableName "WinPrefetchView.exe"
                
                Write-Host "All tools have been run and cleaned up." -ForegroundColor Green
                Read-Host "Press Enter to return to the menu..."
            }
            '6' {
                # Clean all temporary files
                Clean-AllTempFiles
                Read-Host "Press Enter to return to the menu..."
            }
            'q' {
                Write-Host "Exiting ToolHub." -ForegroundColor Green
            }
            default {
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    } while ($selection -ne 'q')

    Write-Host "Thank you for using ToolHub!" -ForegroundColor Cyan
}

# Check if the script is being run directly or through Invoke-Expression
if ($MyInvocation.InvocationName -eq '.') {
    # Script is being run through dot-sourcing or Invoke-Expression
    Start-ToolHub
} elseif ($MyInvocation.Line -eq '') {
    # Script is being run directly
    Start-ToolHub
}
