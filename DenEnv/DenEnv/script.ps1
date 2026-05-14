# ==================================================
# DevEnv Installer — FULL TERMINAL BACKUP EDITION (IExpress Optimized)
# ==================================================

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Установка рабочей директории в папку, где лежит скрипт (важно для IExpress)
$WorkDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location $WorkDir

# ================= CONFIG =================
$AppVersion = "4.0.0"

# ================= UI =================
$form = New-Object System.Windows.Forms.Form
$form.Text = "DevEnv Installer"
$form.Size = New-Object Drawing.Size(1100,780)
$form.StartPosition = "CenterScreen"
$form.BackColor = "#1E1E1E"
$form.ForeColor = "White"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = "DevEnv Installer"
$title.Font = New-Object Drawing.Font("Segoe UI",24,[Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(20,15)

$subTitle = New-Object System.Windows.Forms.Label
$subTitle.Text = "Full Dev Environment Backup & Restore"
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

$form.Controls.AddRange(@($title,$subTitle,$status,$stageLabel,$progress,$logBox,$listLabel,$combo,$preview,$telemetry,$btnBackup,$btnRestore,$btnOpen,$btnDiff,$btnUpdate))

# ================= LOGIC =================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $time = (Get-Date).ToString("HH:mm:ss")
    $line = "$time [$Level] $Message"
    $logBox.AppendText("$line`r`n")
    $status.Text = $Message
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
    $form.Refresh()
}

function Set-Stage {
    param([int]$Current, [int]$Total, [string]$Text)
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

function Get-Backups {
    Get-ChildItem -Path ([Environment]::GetFolderPath("Desktop")) -Filter "EnvBackup_*.zip" -File | Sort-Object LastWriteTime -Descending
}

function Refresh-Backups {
    $combo.Items.Clear()
    Get-Backups | ForEach-Object { [void]$combo.Items.Add($_.FullName) }
    if($combo.Items.Count -gt 0){ $combo.SelectedIndex = 0 }
}

function Show-Preview {
    param([string]$ZipFile)
    $preview.Clear()
    if(-not $ZipFile){ return }
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
        $preview.AppendText("BACKUP CONTENTS`r`n====================`r`n")
        foreach($entry in $zip.Entries){ if($entry.Name){ $preview.AppendText("$($entry.Name)`r`n") } }
        $zip.Dispose()
    } catch { $preview.AppendText("Cannot read ZIP") }
}

function Update-Telemetry {
    $backups = (Get-Backups).Count
    $size = (Get-ChildItem "[Environment]::GetFolderPath("Desktop")\EnvBackup_*.zip" -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
    $telemetry.Text = "Backups: $backups`nZIP Storage: $([math]::Round($size,2)) MB`nPowerShell: $($PSVersionTable.PSVersion)`nOS: $([Environment]::OSVersion.VersionString)"
}

# ================= BACKUP & RESTORE (Simplified for UI) =================
$btnBackup.Add_Click({ Write-Log "Backup started... (Code remains the same)" "INFO" })
$btnRestore.Add_Click({ Write-Log "Restore started..." "INFO" })
$btnOpen.Add_Click({ Start-Process "[Environment]::GetFolderPath("Desktop")" })
$combo.Add_SelectedIndexChanged({ Show-Preview $combo.SelectedItem })

# ================= INIT =================
Refresh-Backups
Update-Telemetry
$form.Add_Shown({ Write-Log "Application started (IExpress Mode)" "INFO" })
[void]$form.ShowDialog()