if (Get-Command -Name Import-LocalScript -ErrorAction SilentlyContinue) {
    . Import-LocalScript -Path (Join-Path $script:AppRoot 'logic\buttonFunctions.ps1')
}
else {
    . "$PSScriptRoot\..\logic\buttonFunctions.ps1"
}

function Set-MenuSizeFromButtons {
    param(
        [Parameter(Mandatory)] $Form,
        [Parameter(Mandatory)] $GroupBox,
        [Parameter(Mandatory)] [array] $Buttons,
        [int] $GroupWidth = 280,
        [int] $BottomPadding = 15,
        [int] $MinGroupHeight = 95
    )

    $maxBottom = 0

    # Calculate maximum bottom position of all buttons
    foreach ($button in $Buttons) {
        $buttonBottom = $button.Location.Y + $button.Height

        # Update the maximum bottom position if the current button's bottom is greater
        if ($buttonBottom -gt $maxBottom) {
            $maxBottom = $buttonBottom
        }
    }

    # Set the group box height based on the maximum bottom position of the buttons plus padding
    $groupHeight = [Math]::Max($MinGroupHeight, $maxBottom + $BottomPadding)
    $GroupBox.Size = New-Object System.Drawing.Size($GroupWidth, $groupHeight)

    # Set the form client size based on the group box size
    $clientWidth = $GroupBox.Location.X + $GroupBox.Width + 10
    $clientHeight = $GroupBox.Location.Y + $GroupBox.Height + 10
    $Form.ClientSize = New-Object System.Drawing.Size($clientWidth, $clientHeight)
}

function Show-CustomClipboardMenu {
    param(
        [Parameter(Mandatory)] [string]$SectionName,
        [Parameter(Mandatory)] $SourceButtons,
        [System.Windows.Forms.Form]$ParentForm = $null,
        [int]$YStart = 30
    )

    $groupTools = New-Object System.Windows.Forms.GroupBox
    $groupTools.Text = ""
    $groupTools.Location = New-Object System.Drawing.Point(10, 10)
    $groupTools.Size = New-Object System.Drawing.Size(280, 390)
    $groupTools.AutoSize = $false

    $form = New-Object System.Windows.Forms.Form
    $form.Text = ""
    $form.Size = New-Object System.Drawing.Size(315, 460)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.ShowIcon = $false

    # Determine the parent form to position the custom clipboard menu relative to it
    $resolvedParentForm = $ParentForm
    # If the provided parent form is null or disposed, try to use the global clipboard parent form
    if ((-not $resolvedParentForm) -or $resolvedParentForm.IsDisposed) {
        $resolvedParentForm = $script:ClipboardParentForm
    }
    # If the global clipboard parent form is also null or disposed, use the active form
    if ((-not $resolvedParentForm) -or $resolvedParentForm.IsDisposed) {
        $resolvedParentForm = $script:activeForm
    }
    # If a valid parent form was found, position the custom clipboard menu relative to it
    if ($resolvedParentForm -and -not $resolvedParentForm.IsDisposed) {
        $form.StartPosition = 'Manual'
        $form.Location = $resolvedParentForm.Location
        $resolvedParentForm.Hide()
    }

    $xPosLeft = 10
    $xPosRight = 150
    $yPos = $YStart
    $rowSpacing = 50

    $buttons = @()
    $normalizedSourceButtons = @($SourceButtons | Where-Object { $_ -ne $null })

    # Load buttons if not empty 
    if ($normalizedSourceButtons.Count -gt 0) {
        $loadResult = Launch-ButtonLoader -Section $SectionName -SourceButtons $normalizedSourceButtons -Buttons ([ref]$buttons) -Layout "TwoColumn" -MaxButtons 10 -XPosLeft $xPosLeft -XPosRight $xPosRight -YStart $yPos -RowSpacing $rowSpacing
    }
    # Default behavior if no buttons are configured with no buttons being configured
    else {
        $lblNoButtons = New-Label "No buttons configured for this menu." 10 $yPos
        $groupTools.Controls.Add($lblNoButtons)
        # Set y position for back button below the "No buttons configured" label
        $loadResult = [PSCustomObject]@{ NextY = ($yPos + 25) }
    }

    $btnBack = New-MenuButton "Back" (New-Object System.Drawing.Point(($xPosLeft + 70), ($loadResult.NextY + 10))) {
        $form.Close()
    }

    $buttons += $btnBack

    $groupTools.Controls.AddRange($buttons)
    $form.Controls.Add($groupTools)

    # Call function to set menu size based on the amount of buttons 
    Set-MenuSizeFromButtons -Form $form -GroupBox $groupTools -Buttons $buttons

    # Show the form and set it as the active form for the hotkey functionality
    $form.Add_Shown({
            $script:activeForm = $form
        })

    # Handle form closing event to restore the parent form
    $form.Add_FormClosing({
            if ($resolvedParentForm -and -not $resolvedParentForm.IsDisposed) {
                $resolvedParentForm.Location = $form.Location
                $resolvedParentForm.Show()
                $resolvedParentForm.BringToFront()
                $resolvedParentForm.Activate()
                $script:activeForm = $resolvedParentForm
            }
        })

    $form.ShowDialog()
}

    
function Invoke-CustomMenuBySlot {
    param(
        [Parameter(Mandatory)] [string]$SlotName,
        [Parameter(Mandatory)] [string]$SectionName,
        [System.Windows.Forms.Form]$ParentForm = $null,
        [int]$YStart = 30
    )

    $customButtons = Import-CustomButtons
    Show-CustomClipboardMenu -SectionName $SectionName -SourceButtons $customButtons.$SlotName -ParentForm $ParentForm -YStart $YStart
}

function Show-CustomMenu1 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom1" -SectionName "Custom Menu 1" -ParentForm $ParentForm -YStart 20
}

function Show-CustomMenu2 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom2" -SectionName "Custom Menu 2" -ParentForm $ParentForm
}

function Show-CustomMenu3 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom3" -SectionName "Custom Menu 3" -ParentForm $ParentForm
}

function Show-CustomMenu4 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom4" -SectionName "Custom Menu 4" -ParentForm $ParentForm
}

function Show-CustomMenu5 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom5" -SectionName "Custom Menu 5" -ParentForm $ParentForm
}

function Show-CustomMenu6 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom6" -SectionName "Custom Menu 6" -ParentForm $ParentForm
}

function Show-CustomMenu7 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom7" -SectionName "Custom Menu 7" -ParentForm $ParentForm
}

function Show-CustomMenu8 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom8" -SectionName "Custom8" -ParentForm $ParentForm
}

function Show-CustomMenu9 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom9" -SectionName "Custom9" -ParentForm $ParentForm
}

function Show-CustomMenu10 {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    Invoke-CustomMenuBySlot -SlotName "Custom10" -SectionName "Custom10" -ParentForm $ParentForm
}