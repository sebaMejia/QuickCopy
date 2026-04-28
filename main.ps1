Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Resolve-AppRoot {
    # Prefer script directory during normal .ps1 runs.
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot) -and (Test-Path (Join-Path $PSScriptRoot 'logic'))) {
        return $PSScriptRoot
    }

    # Fallback for packaged .exe runs where script internals execute from temp.
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Path $exePath -Parent
    if (Test-Path (Join-Path $exeDir 'logic')) {
        return $exeDir
    }

    throw "Unable to resolve application root. Expected a 'logic' folder near script or executable path."
}

function Import-LocalScript {
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Import-LocalScript received an empty path.'
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required script file not found: $Path"
    }

    $scriptContent = Get-Content -LiteralPath $Path -Raw
    . ([scriptblock]::Create($scriptContent))
}

$script:AppRoot = Resolve-AppRoot

. Import-LocalScript -Path (Join-Path $script:AppRoot 'logic\customButtons.ps1')
. Import-LocalScript -Path (Join-Path $script:AppRoot 'settings\settings.ps1')
. Import-LocalScript -Path (Join-Path $script:AppRoot 'clipboard\clipboardMenu.ps1')
. Import-LocalScript -Path (Join-Path $script:AppRoot 'logic\buttonFunctions.ps1')

# Main Form 
$form = New-Object System.Windows.Forms.Form
$form.Text = "IT Clipboard"
$form.Size = New-Object System.Drawing.Size(315, 380)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.ShowIcon = $false

# Track the main form and active form for hotkey functionality
$script:mainForm = $form
$script:activeForm = $form

. Import-LocalScript -Path (Join-Path $script:AppRoot 'logic\hotkeyHideGUI.ps1')

# Calling clipboard groupbox for buttons to display on main form
$clipboardGroupTools = Get-ClipboardGroupBox -ParentForm $form

# Settings button at the bottom of the form
$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "Settings"
$btnSettings.Size = New-Object System.Drawing.Size(280, 30)
$btnSettings.Location = New-Object System.Drawing.Point(10, 300)

# On click, hide the main form and show the settings menu
$btnSettings.Add_Click({
        $form.Hide()
        Get-SettingsMenu -ParentForm $form
        if (-not $form.IsDisposed) {
            $form.Show()
            $form.BringToFront()
            $form.Activate()
        }
    })

$form.Controls.Add($clipboardGroupTools)
$form.Controls.Add($btnSettings)
[void]$form.ShowDialog()
