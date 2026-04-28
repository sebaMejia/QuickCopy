$settingsRoot = if ($script:AppRoot) {
    Join-Path $script:AppRoot 'settings'
}
else {
    $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($settingsRoot)) {
    throw 'Unable to resolve settings root for script imports.'
}

if (Get-Command -Name Import-LocalScript -ErrorAction SilentlyContinue) {
    . Import-LocalScript -Path (Join-Path $script:AppRoot 'logic\customButtons.ps1')
    . Import-LocalScript -Path (Join-Path $script:AppRoot 'logic\textBoxPolicies.ps1')
    . Import-LocalScript -Path (Join-Path $settingsRoot 'addMenu.ps1')
    . Import-LocalScript -Path (Join-Path $settingsRoot 'delMenu.ps1')
    . Import-LocalScript -Path (Join-Path $settingsRoot 'editMenu.ps1')
    . Import-LocalScript -Path (Join-Path $settingsRoot 'hotkeyMenu.ps1')
}
else {
    . "$PSScriptRoot\..\logic\customButtons.ps1"
    . "$PSScriptRoot\..\logic\textBoxPolicies.ps1"
    . "$PSScriptRoot\addMenu.ps1"
    . "$PSScriptRoot\delMenu.ps1"
    . "$PSScriptRoot\editMenu.ps1"
    . "$PSScriptRoot\hotkeyMenu.ps1"
}

function Get-SettingsMenu {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Settings"
    $form.Size = New-Object System.Drawing.Size(300, 440)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $form.ShowIcon = $false

    # Position the settings form relative to the parent form if provided
    if ($ParentForm -and -not $ParentForm.IsDisposed) {
        $form.StartPosition = 'Manual'
        $form.Location = $ParentForm.Location
    }

    $settingsForm = New-Object System.Windows.Forms.GroupBox
    $settingsForm.Location = New-Object System.Drawing.Point(10, 10)
    $settingsForm.Size = New-Object System.Drawing.Size(265, 380)

    $btnEditClipboard = New-Object System.Windows.Forms.Button
    $btnEditClipboard.Text = "Add Buttons"
    $btnEditClipboard.Size = New-Object System.Drawing.Size(205, 40)
    $btnEditClipboard.Location = New-Object System.Drawing.Point(30, 20)
    $btnEditClipboard.Add_Click({
        $form.Hide()
        $returnToSettings = Show-AddButtonMenu -ParentForm $form
        if (-not $form.IsDisposed) {
            if ($returnToSettings) {
                $form.Show()
                $form.BringToFront()
                $form.Activate()
            }
            else {
                $form.Close()
            }
        }
    })

    $editButton = New-Object System.Windows.Forms.Button
    $editButton.Text = "Edit Section/Buttons"
    $editButton.Size = New-Object System.Drawing.Size(205, 40)
    $editButton.Location = New-Object System.Drawing.Point(30, 80)
    $editButton.Add_Click({
        $form.Hide()
        $returnToSettings = Show-EditButtonMenu -ParentForm $form
        if (-not $form.IsDisposed) {
            if ($returnToSettings) {
                $form.Show()
                $form.BringToFront()
                $form.Activate()
            }
            else {
                $form.Close()
            }
        }
    })

    $btnDelButton = New-Object System.Windows.Forms.Button
    $btnDelButton.Text = "Delete Buttons"
    $btnDelButton.Size = New-Object System.Drawing.Size(205, 40)
    $btnDelButton.Location = New-Object System.Drawing.Point(30, 140)
    $btnDelButton.Add_Click({
        $form.Hide()
        $returnToSettings = Show-DeleteButtonMenu -ParentForm $form
        if (-not $form.IsDisposed) {
            if ($returnToSettings) {
                $form.Show()
                $form.BringToFront()
                $form.Activate()
            }
            else {
                $form.Close()
            }
        }
    })

    $btnHotKeySettings = New-Object System.Windows.Forms.Button
    $btnHotKeySettings.Text = 'Hotkey Settings'
    $btnHotKeySettings.Size = New-Object System.Drawing.Size(205, 40)
    $btnHotKeySettings.Location = New-Object System.Drawing.Point(30, 200)
    $btnHotKeySettings.Add_Click({
        $form.Hide()
        $returnToSettings = Show-HotKeySettingsMenu -ParentForm $form
        if (-not $form.IsDisposed) {
            if ($returnToSettings) {
                $form.Show()
                $form.BringToFront()
                $form.Activate()
            }
            else {
                $form.Close()
            }
        }
    })

    $btnResetButton = New-Object System.Windows.Forms.Button
    $btnResetButton.Text = "Reset to Default"
    $btnResetButton.Size = New-Object System.Drawing.Size(205, 40)
    $btnResetButton.Location = New-Object System.Drawing.Point(30, 260)
    $btnResetButton.Add_Click({
        $confirmation = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to reset all custom buttons and sections to their default state? This action cannot be undone.", "Confirm Reset", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirmation -eq [System.Windows.Forms.DialogResult]::Yes) {
            Save-CustomButtons (New-DefaultCustomButtons)
            [System.Windows.Forms.MessageBox]::Show("All buttons have been reset. Please relaunch the application to apply the changes.", "Reset Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
    })

    $btnBack = New-Object System.Windows.Forms.Button
    $btnBack.Text = "Back"
    $btnBack.Size = New-Object System.Drawing.Size(205, 40)
    $btnBack.Location = New-Object System.Drawing.Point(30, 320)
    $btnBack.Add_Click({
        $form.Close()
    })

    $settingsForm.Controls.AddRange(@($btnEditClipboard, $btnDelButton, $editButton, $btnHotKeySettings, $btnResetButton, $btnBack))
    $form.Controls.Add($settingsForm)

    # Set the active form when the settings form is shown
    $form.Add_Shown({
            $script:activeForm = $form
        })
    
    # Handle form closing event to restore the parent form's location and set it as the active form
    $form.Add_FormClosing({
            if ($ParentForm -and -not $ParentForm.IsDisposed) {
                $ParentForm.Location = $form.Location
                $script:activeForm = $ParentForm
            }
        })

    $form.ShowDialog()
}