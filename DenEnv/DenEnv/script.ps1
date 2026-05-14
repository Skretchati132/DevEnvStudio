# ==================================================
# DevEnv Installer — FULL TERMINAL BACKUP EDITION
# ==================================================

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ================= CONFIG =================

$AppVersion = "4.0.0"

# ================= ADMIN =================

function Ensure-Admin {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    if (-not $principal.IsInRole($adminRole)) {

        Start-Process powershell `
            "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs

        exit
    }
}

Ensure-Admin

# ================= UI =================

$form = New-Object System.Windows.Forms.Form
$form.Text = "DevEnv Studio"
$form.Size = New-Object Drawing.Size(1100,780)
$form.StartPosition = "CenterScreen"
$form.BackColor = "#1E1E1E"
$form.ForeColor = "White"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "DevEnv Studio"
$title.Font = New-Object Drawing.Font("Segoe UI",24,[Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(20,15)

$subTitle = New-Object System.Windows.Forms.Label
$subTitle.Text = "Developer Environment Backup & Restore"
$subTitle.Location = New-Object Drawing.Point(25,60)
$subTitle.AutoSize = $true

$status = New-Object System.Windows.Forms.Label
$status.Text = "Ready"
$status.Location = New-Object Drawing.Point(25,90)
$status.Size = New-Object Drawing.Size(900,25)

$stageLabel = New-Object System.Windows.Forms.Label
$stageLabel.Text = "[0/0]"
$stageLabel.Location = New-Object Drawing.Point(950,90)
$stageLabel.Size = New-Object Drawing.Size(100,25)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object Drawing.Point(25,120)
$progress.Size = New-Object Drawing.Size(1020,28)
$progress.Style = "Continuous"

# ================= LOG =================

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object Drawing.Point(25,170)
$logBox.Size = New-Object Drawing.Size(1020,350)
$logBox.BackColor = "#111111"
$logBox.ForeColor = "#00FF88"
$logBox.Font = New-Object Drawing.Font("Consolas",10)
$logBox.ReadOnly = $true

$listLabel = New-Object System.Windows.Forms.Label
$listLabel.Text = "Available ZIP Backups"
$listLabel.Location = New-Object Drawing.Point(25,540)
$listLabel.AutoSize = $true

$combo = New-Object System.Windows.Forms.ComboBox
$combo.Location = New-Object Drawing.Point(25,565)
$combo.Size = New-Object Drawing.Size(650,30)
$combo.DropDownStyle = "DropDownList"

$preview = New-Object System.Windows.Forms.RichTextBox
$preview.Location = New-Object Drawing.Point(700,565)
$preview.Size = New-Object Drawing.Size(345,140)
$preview.BackColor = "#151515"
$preview.ForeColor = "#FFFFFF"
$preview.Font = New-Object Drawing.Font("Consolas",10)
$preview.ReadOnly = $true

$telemetry = New-Object System.Windows.Forms.Label
$telemetry.Location = New-Object Drawing.Point(25,610)
$telemetry.Size = New-Object Drawing.Size(650,90)

# ================= BUTTONS =================

function New-UIBtn($text,$x,$y,$color){

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object Drawing.Point($x,$y)
    $btn.Size = New-Object Drawing.Size(190,45)
    $btn.BackColor = $color
    $btn.ForeColor = "White"
    $btn.FlatStyle = "Flat"

    return $btn
}

$btnBackup = New-UIBtn "CREATE BACKUP" 25 710 "#007ACC"
$btnRestore = New-UIBtn "RESTORE" 240 710 "#28A745"
$btnOpen = New-UIBtn "OPEN BACKUPS" 455 710 "#6C757D"
$btnDiff = New-UIBtn "COMPARE BACKUPS" 670 710 "#AA00FF"
$btnUpdate = New-UIBtn "CHECK UPDATES" 885 710 "#FF8800"

$form.Controls.AddRange(@(
    $title,
    $subTitle,
    $status,
    $stageLabel,
    $progress,
    $logBox,
    $listLabel,
    $combo,
    $preview,
    $telemetry,
    $btnBackup,
    $btnRestore,
    $btnOpen,
    $btnDiff,
    $btnUpdate
))

# ================= LOGIC =================

function Write-Log {

    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $time = (Get-Date).ToString("HH:mm:ss")

    $line = "$time [$Level] $Message"

    $logBox.AppendText("$line`r`n")

    $status.Text = $Message

    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()

    $form.Refresh()
}

function Set-Stage {

    param(
        [int]$Current,
        [int]$Total,
        [string]$Text
    )

    $stageLabel.Text = "[$Current/$Total]"

    Write-Log $Text "STEP"
}

function Set-Progress {

    param([int]$Value)

    if($Value -lt 0){ $Value = 0 }
    if($Value -gt 100){ $Value = 100 }

    $progress.Value = $Value

    $form.Refresh()
}

function New-TempFolder {

    $guid = [guid]::NewGuid().ToString()

    $temp = Join-Path $env:TEMP "DevEnv_$guid"

    New-Item `
        -ItemType Directory `
        -Path $temp |
    Out-Null

    return $temp
}

function Expand-BackupZip {

    param([string]$Zip)

    $temp = New-TempFolder

    Expand-Archive `
        -Path $Zip `
        -DestinationPath $temp `
        -Force

    return $temp
}

function Get-Backups {

    Get-ChildItem `
        -Path (Get-Location) `
        -Filter "EnvBackup_*.zip" `
        -File |
    Sort-Object LastWriteTime -Descending
}
function Refresh-Backups {

    $combo.Items.Clear()

    $backupFiles = @()

    # =========================
    # Fast paths only
    # =========================

    $searchPaths = @(
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("MyDocuments"),
        "$env:USERPROFILE\Downloads"
    )

    foreach ($path in $searchPaths) {

        if (-not (Test-Path $path)) {
            continue
        }

        try {

            $files = Get-ChildItem `
                -Path $path `
                -Filter "EnvBackup_*.zip" `
                -File `
                -ErrorAction SilentlyContinue

            if ($files) {
                $backupFiles += $files
            }

        } catch {

        }
    }

    # =========================
    # Remove duplicates
    # =========================

    $backupFiles = $backupFiles |
        Sort-Object FullName -Unique

    # =========================
    # Sort newest first
    # =========================

    $backupFiles = $backupFiles |
        Sort-Object LastWriteTime -Descending

    # =========================
    # Fill combo
    # =========================

    foreach ($file in $backupFiles) {

        $combo.Items.Add($file.FullName)
    }

    if ($combo.Items.Count -gt 0) {

        $combo.SelectedIndex = 0
    }
}
function Show-Preview {

    param([string]$ZipFile)

    $preview.Clear()

    if(-not $ZipFile){
        return
    }

    try {

        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)

        $preview.AppendText("BACKUP CONTENTS`r`n")
        $preview.AppendText("====================`r`n")

        foreach($entry in $zip.Entries){

            if($entry.Name){

                $preview.AppendText("$($entry.Name)`r`n")
            }
        }

        $zip.Dispose()
    }
    catch {

        $preview.AppendText("Cannot read ZIP")
    }
}

function Update-Telemetry {

    $backups = (Get-Backups).Count

    $size = (
        Get-ChildItem *.zip -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum
    ).Sum / 1MB

    $telemetry.Text = @"
Backups: $backups
ZIP Storage: $([math]::Round($size,2)) MB
PowerShell: $($PSVersionTable.PSVersion)
OS: $([Environment]::OSVersion.VersionString)
"@
}

# ================= BACKUP =================

function Run-Backup {

    try {

        Set-Stage 1 9 "Creating temp workspace"
        Set-Progress 5

        $time = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

        $tempFolder = Join-Path `
            $env:TEMP `
            "EnvBackup_$time"

        New-Item `
            -ItemType Directory `
            -Path $tempFolder |
        Out-Null

        # ================= PROFILE =================

        Set-Stage 2 9 "Saving PowerShell profile"
        Set-Progress 15

        $profilePath = $PROFILE

        if([string]::IsNullOrWhiteSpace($profilePath)){

            $profilePath = Join-Path `
                $HOME `
                "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        }

        Write-Log "Profile path: $profilePath"

        if(Test-Path $profilePath){

            Copy-Item `
                $profilePath `
                "$tempFolder\PowerShell_Profile.ps1" `
                -Force

            Write-Log "PowerShell profile saved" "SUCCESS"
        }
        else {

            Write-Log "PowerShell profile not found" "WARN"
        }

        # ================= CMD SETTINGS =================

        Set-Stage 3 9 "Saving CMD settings"
        Set-Progress 25

        reg export HKCU\Console `
            "$tempFolder\console.reg" `
            /y | Out-Null

        Write-Log "CMD settings saved" "SUCCESS"

        # ================= WINDOWS TERMINAL =================

        Set-Stage 4 9 "Saving Windows Terminal"
        Set-Progress 35

        $wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

        if(Test-Path $wt){

            Copy-Item `
                $wt `
                "$tempFolder\windows_terminal.json"

            Write-Log "Windows Terminal settings saved" "SUCCESS"
        }
        else {

            Write-Log "Windows Terminal not installed" "WARN"
        }

        # ================= PACKAGES =================

        Set-Stage 5 9 "Exporting packages"
        Set-Progress 50

        winget export `
            -o "$tempFolder\winget-packages.json"

        npm list -g --depth=0 |
            Out-File "$tempFolder\npm.txt"

        pip freeze |
            Out-File "$tempFolder\pip.txt"

        Write-Log "Package lists exported" "SUCCESS"

        # ================= VSCODE =================

        Set-Stage 6 9 "Saving VSCode"
        Set-Progress 65

        if(Get-Command code -ErrorAction SilentlyContinue){

            code --list-extensions |
                Out-File "$tempFolder\vscode_extensions.txt"

            Write-Log "VSCode extensions exported" "SUCCESS"
        }
        else {

            Write-Log "VSCode CLI not found" "WARN"
        }

        # ================= ENV =================

        Set-Stage 7 9 "Saving environment"
        Set-Progress 75

        Get-ChildItem Env: |
            Export-CliXml "$tempFolder\custom_env.xml"

        Write-Log "Environment variables exported" "SUCCESS"

        # ================= MANIFEST =================

        Set-Stage 8 9 "Creating manifest"
        Set-Progress 85

        @{
            created = Get-Date
            machine = $env:COMPUTERNAME
            powershell = $PSVersionTable.PSVersion.ToString()
            os = [Environment]::OSVersion.VersionString
        } |
        ConvertTo-Json |
        Out-File "$tempFolder\manifest.json"

        Write-Log "Manifest created" "SUCCESS"

        # ================= ZIP =================

        Set-Stage 9 9 "Compressing ZIP"
        Set-Progress 95

        $DesktopPath = [Environment]::GetFolderPath("Desktop")

        $zipFile = Join-Path `
           $DesktopPath `
        "EnvBackup_$time.zip"

        Compress-Archive `
            -Path "$tempFolder\*" `
            -DestinationPath $zipFile `
            -CompressionLevel Optimal

        Remove-Item `
            $tempFolder `
            -Recurse `
            -Force

        Write-Log "Temporary workspace removed" "INFO"

        Set-Progress 100

        Write-Log "ZIP backup created" "SUCCESS"

        Refresh-Backups
        Update-Telemetry
    }
    catch {

        Write-Log $_.Exception.Message "ERROR"
    }
}

# ================= RESTORE =================

function Run-Restore {

    try {

        $zip = $combo.SelectedItem

        if(-not $zip){

            throw "No ZIP selected"
        }

        Write-Log "Extracting ZIP..." "STEP"

        $temp = Expand-BackupZip $zip

        # ================= PROFILE =================

        $profileBackup = "$temp\PowerShell_Profile.ps1"

        if(Test-Path $profileBackup){

            $profileDir = Split-Path $PROFILE

            if(-not (Test-Path $profileDir)){

                New-Item `
                    -ItemType Directory `
                    -Path $profileDir `
                    -Force |
                Out-Null
            }

            Copy-Item `
                $profileBackup `
                $PROFILE `
                -Force

            Write-Log "PowerShell profile restored" "SUCCESS"
        }

        # ================= CMD =================

        if(Test-Path "$temp\console.reg"){

            reg import "$temp\console.reg" | Out-Null

            Write-Log "CMD settings restored" "SUCCESS"
        }

        # ================= TERMINAL =================

        if(Test-Path "$temp\windows_terminal.json"){

            $wtDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"

            if(-not (Test-Path $wtDir)){

                New-Item `
                    -ItemType Directory `
                    -Path $wtDir `
                    -Force |
                Out-Null
            }

            Copy-Item `
                "$temp\windows_terminal.json" `
                "$wtDir\settings.json" `
                -Force

            Write-Log "Windows Terminal restored" "SUCCESS"
        }

        # ================= PIP =================

        if(Test-Path "$temp\pip.txt"){

            Get-Content "$temp\pip.txt" | ForEach-Object {

                if($_){

                    Write-Log "Installing pip: $_"

                    pip install $_
                }
            }
        }

        # ================= NPM =================

        if(Test-Path "$temp\npm.txt"){

            Get-Content "$temp\npm.txt" | ForEach-Object {

                if($_ -match '── (.+)@'){

                    npm install -g $matches[1]
                }
            }
        }

        # ================= VSCODE =================

        if(Test-Path "$temp\vscode_extensions.txt"){

            Get-Content "$temp\vscode_extensions.txt" | ForEach-Object {

                code --install-extension $_ --force
            }

            Write-Log "VSCode extensions restored" "SUCCESS"
        }

        Remove-Item `
            $temp `
            -Recurse `
            -Force

        Write-Log "Temporary files removed" "INFO"

        Write-Log "Restore complete" "SUCCESS"
    }
    catch {

        Write-Log $_.Exception.Message "ERROR"
    }
}

# ================= COMPARE =================

function Compare-Backups {

    $backups = Get-Backups

    if($backups.Count -lt 2){

        Write-Log "Need at least 2 backups" "WARN"
        return
    }

    $old = $backups[1].FullName
    $new = $backups[0].FullName

    $oldTemp = Expand-BackupZip $old
    $newTemp = Expand-BackupZip $new

    try {

        Write-Log "Comparing backups..." "STEP"

        $oldPip = Get-Content "$oldTemp\pip.txt"
        $newPip = Get-Content "$newTemp\pip.txt"

        Compare-Object $oldPip $newPip | ForEach-Object {

            Write-Log $_ "INFO"
        }
    }
    finally {

        Remove-Item $oldTemp -Recurse -Force
        Remove-Item $newTemp -Recurse -Force

        Write-Log "Temporary compare files removed" "INFO"
    }
}

# ================= EVENTS =================

$btnBackup.Add_Click({ Run-Backup })

$btnRestore.Add_Click({ Run-Restore })

$btnOpen.Add_Click({

    Start-Process (Get-Location)
})

$btnDiff.Add_Click({

    Compare-Backups
})

$btnUpdate.Add_Click({

    Write-Log "Update system disabled" "WARN"
})

$combo.Add_SelectedIndexChanged({

    Show-Preview $combo.SelectedItem
})

# ================= INIT =================

Refresh-Backups
Update-Telemetry

$form.Add_Shown({

    Write-Log "Application started" "INFO"

    if($combo.Items.Count -gt 0){

        Show-Preview $combo.SelectedItem
    }
})

# ================= START =================

[void]$form.ShowDialog()