$clipboardRoot = if ($script:AppRoot) {
    Join-Path $script:AppRoot 'clipboard'
}
else {
    $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($clipboardRoot)) {
    throw 'Unable to resolve clipboard root for script imports.'
}

if (Get-Command -Name Import-LocalScript -ErrorAction SilentlyContinue) {
    . Import-LocalScript -Path (Join-Path $clipboardRoot 'clipboardGUI.ps1')
}
else {
    . "$PSScriptRoot\clipboardGUI.ps1"
}

function Get-ClipboardGroupBox {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    # Persist parent form reference for button click handlers.
    $script:ClipboardParentForm = $ParentForm

    $groupTools = New-Object System.Windows.Forms.GroupBox
    $groupTools.Location = New-Object System.Drawing.Point(10, 10)
    $groupTools.Size = New-Object System.Drawing.Size(280, 280)

    # Load custom buttons configuration from logic\customButtons.ps1
    $customButtons = Import-CustomButtons

    function Get-SectionHeader {
        param([string]$CustomSlot)

        # Load existing button configuration for the specified custom slot
        $buttons = @($customButtons.$CustomSlot)

        # From buttons, get the first non-empty section header and return it 
        $headerFromButtons = $buttons |
        ForEach-Object { $_.'Section Header' } |
        Where-Object { $_ -and $_.ToString().Trim() } |
        Select-Object -First 1
        
        if ($headerFromButtons) {
            return $headerFromButtons.ToString()
        }

        # If no section header was found in the buttons, check the saved section headers in the custom buttons configuration
        if ($customButtons.PSObject.Properties.Name -contains 'SectionHeaders') {
            # Retrieve the saved section header for the custom slot
            $savedHeader = $customButtons.SectionHeaders.PSObject.Properties[$CustomSlot]
            # Check if a saved section header exists for the custom slot
            if ($savedHeader -and -not [string]::IsNullOrWhiteSpace([string]$savedHeader.Value)) {
                # Return the saved section header for the custom slot
                return [string]$savedHeader.Value
            }
        }
        return $CustomSlot
    }
    
    $menuButtons = @()
    for ($index = 1; $index -le 10; $index++) {
        $slot = "Custom$index"
        $label = Get-SectionHeader $slot

        $xPos = if ($index % 2 -eq 1) { 10 } else { 150 }
        $row = [Math]::Floor(($index - 1) / 2)
        $yPos = 20 + ($row * 50)

        $showFunction = "Show-CustomMenu$index"
        $btn = New-MenuButton $label (New-Object System.Drawing.Point($xPos, $yPos)) {
            & $showFunction -ParentForm $script:ClipboardParentForm
        }.GetNewClosure()

        $menuButtons += $btn
    }

    $groupTools.Controls.AddRange($menuButtons)

    return $groupTools
}
