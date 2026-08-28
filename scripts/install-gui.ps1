$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$packageRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $PSScriptRoot 'install.ps1'
if (-not (Test-Path $installer)) { throw "Installer not found: $installer" }

$form = New-Object System.Windows.Forms.Form
$form.Text = 'PUNTASH QA - Easy Start'
$form.Size = New-Object System.Drawing.Size(720,330)
$form.StartPosition = 'CenterScreen'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.FormBorderStyle = 'FixedDialog'

$title = New-Object System.Windows.Forms.Label
$title.Location = New-Object System.Drawing.Point(24,20)
$title.Size = New-Object System.Drawing.Size(660,45)
$title.Font = New-Object System.Drawing.Font('Segoe UI',14,[System.Drawing.FontStyle]::Bold)
$title.Text = 'Install PUNTASH QA into your project'
$form.Controls.Add($title)

$info = New-Object System.Windows.Forms.Label
$info.Location = New-Object System.Drawing.Point(25,68)
$info.Size = New-Object System.Drawing.Size(655,48)
$info.Text = "Choose the root folder of the project you want to test.`r`nThe installer will create only a .comprehensive-qa folder inside it."
$form.Controls.Add($info)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(25,130)
$pathBox.Size = New-Object System.Drawing.Size(535,27)
$pathBox.ReadOnly = $true
$form.Controls.Add($pathBox)

$browse = New-Object System.Windows.Forms.Button
$browse.Location = New-Object System.Drawing.Point(570,127)
$browse.Size = New-Object System.Drawing.Size(110,32)
$browse.Text = 'Browse...'
$form.Controls.Add($browse)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(25,172)
$status.Size = New-Object System.Drawing.Size(655,38)
$status.Text = 'No project selected.'
$form.Controls.Add($status)

$install = New-Object System.Windows.Forms.Button
$install.Location = New-Object System.Drawing.Point(455,230)
$install.Size = New-Object System.Drawing.Size(110,38)
$install.Text = 'Continue'
$install.Enabled = $false
$form.Controls.Add($install)

$cancel = New-Object System.Windows.Forms.Button
$cancel.Location = New-Object System.Drawing.Point(570,230)
$cancel.Size = New-Object System.Drawing.Size(110,38)
$cancel.Text = 'Cancel'
$form.Controls.Add($cancel)

$script:selected = $null
$script:continueInstall = $false
$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the root folder of the project to protect with Comprehensive QA'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:selected = $dialog.SelectedPath
        $pathBox.Text = $script:selected
        if (Test-Path $script:selected -PathType Container) {
            $existing = Join-Path $script:selected '.comprehensive-qa'
            if (Test-Path $existing) {
                $status.Text = 'A .comprehensive-qa installation already exists here. Use the updater instead of reinstalling.'
                $install.Enabled = $false
            } else {
                $status.Text = 'Project selected. Continue to the required human terms review.'
                $install.Enabled = $true
            }
        }
    }
})
$install.Add_Click({ $script:continueInstall = $true; $form.Close() })
$cancel.Add_Click({ $script:continueInstall = $false; $form.Close() })
[void]$form.ShowDialog()
$form.Dispose()

if (-not $script:continueInstall -or -not $script:selected) { exit 4 }

$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path $windowsPowerShell)) { $windowsPowerShell = 'powershell.exe' }
$args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $installer),'-ProjectPath',('"{0}"' -f $script:selected))
$p = Start-Process -FilePath $windowsPowerShell -ArgumentList $args -Wait -PassThru

if ($p.ExitCode -eq 0) {
    $doctorPath = Join-Path $script:selected '.comprehensive-qa\state\QA_DOCTOR.md'
    $message = "Installation completed successfully.`r`n`r`nProject:`r`n$script:selected`r`n`r`nNext: open your AI agent and ask it to read .comprehensive-qa/START_HERE.md."
    if (Test-Path $doctorPath) { $message += "`r`n`r`nQA Doctor readiness report was created." }
    [System.Windows.Forms.MessageBox]::Show($message,'QA System Installed',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
} elseif ($p.ExitCode -ne 4) {
    [System.Windows.Forms.MessageBox]::Show("Installation did not complete. Exit code: $($p.ExitCode)",'QA System Installation',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
}
exit $p.ExitCode
