# Functions for managing delete menu sections
function Get-DeleteMenuSectionHeaderForSlot {
    param(
        [string]$SlotName
    )
    
    # Get section header for specified slot
    if ([string]::IsNullOrWhiteSpace($SlotName)) {
        return ""
    }

    # Load custom buttons from storage.
    $buttons = Import-CustomButtons
    
    # Get existing buttons for the specified slot
    $existingButtons = @($buttons.$SlotName)

    # Get the first non-empty section header from existing buttons.
    $existingHeader = $existingButtons |
    ForEach-Object { $_.'Section Header' } |
    Where-Object { $_ -and $_.ToString().Trim() } |
    Select-Object -First 1

    # If existing header is found, return it as a string
    if ($existingHeader) {
        return $existingHeader.ToString()
    }

    return ""
}

# Build combo box items for delete menu sections.
function Get-DeleteMenuSectionComboItems {
    $items = @()

    # For each custom button section, get the display name for the combo box
    foreach ($slot in $script:CustomButtonSections) {

        # Get section header for the current slot.
        $header = Get-DeleteMenuSectionHeaderForSlot -SlotName $slot

        # If no header is found, use the slot name as the display name
        $display = if ([string]::IsNullOrWhiteSpace($header)) { $slot } else { $header }

        # Add item to the list of combo box items
        $items += [pscustomobject]@{
            SlotKey     = $slot
            DisplayName = $display
        }
    }

    return $items
}

function Set-DeleteMenuSectionCombo {
    param(
        [System.Windows.Forms.ComboBox]$SlotCombo
    )

    $SlotCombo.Items.Clear()
    
    # Populate combo box with delete menu section items
    foreach ($item in @(Get-DeleteMenuSectionComboItems)) {
        [void]$SlotCombo.Items.Add($item)
    }
}

function Get-DeleteMenuSelectedSlotKey {
    param(
        [System.Windows.Forms.ComboBox]$SlotCombo
    )

    $selectedItem = $SlotCombo.SelectedItem

    # If a valid item is selected, return its slotkey 
    if ($selectedItem -and $selectedItem.PSObject.Properties['SlotKey']) {
        return [string]$selectedItem.SlotKey
    }

    # If no valid item is selected, check the SelectedValue property
    if (-not [string]::IsNullOrWhiteSpace($SlotCombo.SelectedValue)) {
        return [string]$SlotCombo.SelectedValue
    }

    return ""
}

function Show-DeleteButtonMenu {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    $delButtonForm = New-Object System.Windows.Forms.Form
    $delButtonForm.Text = "Delete Custom Button"
    $delButtonForm.Size = New-Object System.Drawing.Size(320, 190)
    $delButtonForm.StartPosition = 'CenterScreen'
    $delButtonForm.FormBorderStyle = 'FixedSingle'
    $delButtonForm.MaximizeBox = $false
    $delButtonForm.ShowIcon = $false

    # If a parent form is provided, position the delete button form relative to it
    if ($ParentForm -and -not $ParentForm.IsDisposed) {
        $delButtonForm.StartPosition = 'Manual'
        $delButtonForm.Location = $ParentForm.Location
    }

    $labelSlot = New-Object System.Windows.Forms.Label
    $labelSlot.Text = "Section:"
    $labelSlot.Location = New-Object System.Drawing.Point(15, 20)
    $labelSlot.Size = New-Object System.Drawing.Size(80, 20)
    $labelSlot.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    $comboSlot = New-Object System.Windows.Forms.ComboBox
    $comboSlot.Location = New-Object System.Drawing.Point(100, 20)
    $comboSlot.Size = New-Object System.Drawing.Size(170, 20)
    $comboSlot.DropDownStyle = 'DropDownList'
    $comboSlot.DisplayMember = 'DisplayName'
    $comboSlot.ValueMember = 'SlotKey'

    # Populate the combo box with delete menu section items
    Set-DeleteMenuSectionCombo -SlotCombo $comboSlot

    $labelButtonSelect = New-Object System.Windows.Forms.Label
    $labelButtonSelect.Text = "Button:"
    $labelButtonSelect.Location = New-Object System.Drawing.Point(15, 60)
    $labelButtonSelect.Size = New-Object System.Drawing.Size(80, 20)
    $labelButtonSelect.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    $comboDeleteButton = New-Object System.Windows.Forms.ComboBox
    $comboDeleteButton.Location = New-Object System.Drawing.Point(100, 60)
    $comboDeleteButton.Size = New-Object System.Drawing.Size(170, 20)
    $comboDeleteButton.DropDownStyle = 'DropDownList'

    $btnDeleteButton = New-Object System.Windows.Forms.Button
    $btnDeleteButton.Text = "Delete"
    $btnDeleteButton.Location = New-Object System.Drawing.Point(130, 100)
    $btnDeleteButton.Size = New-Object System.Drawing.Size(60, 28)
    $btnDeleteButton.Add_Click({
            # Get the selected slot key from the combo box
            $selectedSlot = Get-DeleteMenuSelectedSlotKey -SlotCombo $comboSlot
            if ([string]::IsNullOrWhiteSpace($selectedSlot)) {
                [System.Windows.Forms.MessageBox]::Show("Please select a section.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }

            # Get the selected index of the button to delete
            $selectedIndex = $comboDeleteButton.SelectedIndex

            # Validate the selected index if it is less than 0
            if ($selectedIndex -lt 0) {
                [System.Windows.Forms.MessageBox]::Show("Please select a button to delete.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
            
            $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete this button?", "Confirm Deletion", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                return
            }

            $buttons = Import-CustomButtons
            
            # Get the list of buttons for the selected slot
            $buttonList = @($buttons.$selectedSlot)
            $newButtonList = @()

            # For each button in the list, add it to the new list if it is not the selected index to be deleted
            for ($i = 0; $i -lt $buttonList.Count; $i++) {
                if ($i -ne $selectedIndex) {
                    $newButtonList += $buttonList[$i]
                }
            }
            # Update the buttons for the selected slot
            $buttons.$selectedSlot = $newButtonList

            # Save the updated buttons
            Save-CustomButtons $buttons
            [System.Windows.Forms.MessageBox]::Show("The button was deleted successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

            # Refresh the combo box to reflect the updated list of buttons
            Set-DeleteMenuSectionCombo -SlotCombo $comboSlot
            foreach ($item in $comboSlot.Items) {
                if ($item.SlotKey -eq $selectedSlot) {
                    $comboSlot.SelectedItem = $item
                    break
                }
            }

            # If no item is selected, select the first item in the combo box
            if (-not $comboSlot.SelectedItem -and $comboSlot.Items.Count -gt 0) {
                $comboSlot.SelectedIndex = 0
            }
        })

    # Refreshes the button combo box based on the selected slot
    $refreshButtonCombo = {
        $selected = Get-DeleteMenuSelectedSlotKey -SlotCombo $comboSlot

        if (-not $selected) {
            $comboDeleteButton.Items.Clear()
            $delButtonForm.ActiveControl = $null
            return
        }

        $buttons = Import-CustomButtons
        $existingButtons = @($buttons.$selected)

        $comboDeleteButton.Items.Clear()

        foreach ($btn in $existingButtons) {
            [void]$comboDeleteButton.Items.Add($btn.Text)
        }

        # Remove focus/blue highlight from combo box
        $delButtonForm.ActiveControl = $null
    }

    $comboSlot.Add_SelectedIndexChanged({
            & $refreshButtonCombo
        })
        
    $btnBack = New-Object System.Windows.Forms.Button
    $btnBack.Text = "Back"
    $btnBack.Location = New-Object System.Drawing.Point(210, 100)
    $btnBack.Size = New-Object System.Drawing.Size(60, 28)

    # Clear focus from combo boxes
    $clearComboFocus = {
        $delButtonForm.ActiveControl = $null
    }

    $btnBack.Add_Click({
            $delButtonForm.Close()
        })
    
    # Remove focus from the combo boxes when the user interacts with them
    $comboSlot.Add_Leave({
            & $clearComboFocus
        })

    $comboDeleteButton.Add_SelectedIndexChanged({
            & $clearComboFocus
        })

    $comboDeleteButton.Add_Leave({
            & $clearComboFocus
        })

    $delButtonForm.Add_MouseDown({
            & $clearComboFocus
        })

    $labelSlot.Add_MouseDown({
            & $clearComboFocus
        })

    $labelButtonSelect.Add_MouseDown({
            & $clearComboFocus
        })

    $delButtonForm.Controls.AddRange(@(
            $labelSlot,
            $comboSlot,
            $labelButtonSelect,
            $comboDeleteButton,
            $btnDeleteButton,
            $btnBack
        ))

    $delButtonForm.Add_Shown({
            $script:activeForm = $delButtonForm
            if ($comboSlot.Items.Count -gt 0) {
                $comboSlot.SelectedIndex = 0
            }
            & $clearComboFocus
        })

    $delButtonForm.Add_FormClosing({
            if ($ParentForm -and -not $ParentForm.IsDisposed) {
                $ParentForm.Location = $delButtonForm.Location
                $script:activeForm = $ParentForm
            }
        })

    $delButtonForm.ShowDialog()
}