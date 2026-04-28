function Get-EditMenuSectionHeaderForSlot {
    param(
        [string]$SlotName
    )

    if ([string]::IsNullOrWhiteSpace($SlotName)) {
        return ""
    }

    # 
    $buttons = Import-CustomButtons
    $existingButtons = @($buttons.$SlotName)

    $existingHeader = $existingButtons |
    ForEach-Object { $_.'Section Header' } |
    Where-Object { $_ -and $_.ToString().Trim() } |
    Select-Object -First 1

    if ($existingHeader) {
        return $existingHeader.ToString()
    }

    if ($buttons.PSObject.Properties.Name -contains 'SectionHeaders') {
        $savedHeader = $buttons.SectionHeaders.PSObject.Properties[$SlotName]
        if ($savedHeader -and -not [string]::IsNullOrWhiteSpace([string]$savedHeader.Value)) {
            return [string]$savedHeader.Value
        }
    }

    return ""
}

function Get-EditMenuSectionComboItems {
    $items = @()

    foreach ($slot in $script:CustomButtonSections) {
        $header = Get-EditMenuSectionHeaderForSlot -SlotName $slot
        $display = if ([string]::IsNullOrWhiteSpace($header)) { $slot } else { $header }

        $items += [pscustomobject]@{
            SlotKey     = $slot
            DisplayName = $display
        }
    }

    return $items
}

function Set-EditMenuSectionCombo {
    param(
        [System.Windows.Forms.ComboBox]$SlotCombo
    )

    $SlotCombo.Items.Clear()
    foreach ($item in @(Get-EditMenuSectionComboItems)) {
        [void]$SlotCombo.Items.Add($item)
    }
}

function Get-EditMenuSelectedSlotKey {
    param(
        [System.Windows.Forms.ComboBox]$SlotCombo
    )

    $selectedItem = $SlotCombo.SelectedItem
    if ($selectedItem -and $selectedItem.PSObject.Properties['SlotKey']) {
        return [string]$selectedItem.SlotKey
    }

    if (-not [string]::IsNullOrWhiteSpace($SlotCombo.SelectedValue)) {
        return [string]$SlotCombo.SelectedValue
    }

    return ""
}

function Update-EditMenuButtonList {
    param(
        [System.Windows.Forms.ComboBox]$ButtonCombo,
        [string]$SectionName
    )

    $ButtonCombo.Items.Clear()
    if ([string]::IsNullOrWhiteSpace($SectionName)) {
        return
    }

    $buttons = Import-CustomButtons
    foreach ($btn in @($buttons.$SectionName)) {
        $ButtonCombo.Items.Add($btn.Text)
    }
}

function Get-EditMenuMatchedButton {
    param(
        [string]$SectionName,
        [string]$ButtonText
    )

    if ([string]::IsNullOrWhiteSpace($SectionName) -or [string]::IsNullOrWhiteSpace($ButtonText)) {
        return $null
    }

    $buttons = Import-CustomButtons
    return @($buttons.$SectionName) | Where-Object { $_.Text -eq $ButtonText } | Select-Object -First 1
}

function Get-EditMenuButtonDisplayText {
    param($ButtonData)

    if (-not $ButtonData) {
        return ""
    }

    if (-not [string]::IsNullOrWhiteSpace($ButtonData.Command)) {
        return $ButtonData.Command
    }

    if (-not [string]::IsNullOrWhiteSpace($ButtonData.FilePath)) {
        $filePathText = [string]$ButtonData.FilePath
        $baseRoot = if (-not [string]::IsNullOrWhiteSpace($script:AppRoot)) {
            $script:AppRoot
        }
        elseif (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
            Split-Path $PSScriptRoot -Parent
        }
        else {
            ''
        }

        $fullPath = if ([System.IO.Path]::IsPathRooted($filePathText)) {
            $filePathText
        }
        elseif (-not [string]::IsNullOrWhiteSpace($baseRoot)) {
            Join-Path $baseRoot $filePathText
        }
        else {
            ''
        }

        if (Test-Path $fullPath) {
            return Get-Content -Path $fullPath -Raw
        }
    }

    return ""
}

function Rename-ButtonSection {
    param(
        [string]$OldName,
        [string]$NewName
    )

    if ([string]::IsNullOrWhiteSpace($OldName) -or [string]::IsNullOrWhiteSpace($NewName)) {
        return $false
    }

    $buttons = Import-CustomButtons

    if (-not ($buttons.PSObject.Properties.Name -contains 'SectionHeaders')) {
        $buttons | Add-Member -MemberType NoteProperty -Name SectionHeaders -Value ([pscustomobject]@{})
    }

    if ($buttons.SectionHeaders.PSObject.Properties.Name -contains $OldName) {
        $buttons.SectionHeaders.$OldName = $NewName
    }
    else {
        $buttons.SectionHeaders | Add-Member -MemberType NoteProperty -Name $OldName -Value $NewName
    }

    foreach ($btn in @($buttons.$OldName)) {
        if ($btn.PSObject.Properties.Name -contains 'Section Header') {
            $btn.'Section Header' = $NewName
        }
        else {
            $btn | Add-Member -MemberType NoteProperty -Name 'Section Header' -Value $NewName
        }
    }

    Save-CustomButtons $buttons
    return $true
}

function Save-EditedButtonText {
    param(
        [string]$SectionName,
        [string]$ButtonName,
        [string]$NewText
    )

    if ([string]::IsNullOrWhiteSpace($SectionName) -or [string]::IsNullOrWhiteSpace($ButtonName)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a button to save.")
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($NewText)) {
        [System.Windows.Forms.MessageBox]::Show("Button text cannot be empty.")
        return $false
    }

    $buttons = Import-CustomButtons
    $matchedButton = @($buttons.$SectionName) | Where-Object { $_.Text -eq $ButtonName } | Select-Object -First 1

    if (-not $matchedButton) {
        [System.Windows.Forms.MessageBox]::Show("Could not find the selected button in this section.")
        return $false
    }

    if ($matchedButton.PSObject.Properties.Name -contains 'Command') {
        $matchedButton.Command = $NewText
    }
    else {
        $matchedButton | Add-Member -MemberType NoteProperty -Name Command -Value $NewText
    }

    Save-CustomButtons $buttons
    [System.Windows.Forms.MessageBox]::Show("Button text saved successfully. Please relaunch the application to see changes.")
    return $true
}

function Save-RenamedButton {
    param(
        [string]$SectionName,
        [string]$OldButtonName,
        [string]$NewButtonName
    )

    if ([string]::IsNullOrWhiteSpace($SectionName) -or [string]::IsNullOrWhiteSpace($OldButtonName)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a section and button first.")
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($NewButtonName)) {
        [System.Windows.Forms.MessageBox]::Show("Please have something there.")
        return $false
    }

    $normalizedNewButtonName = $NewButtonName.Trim()

    if ($normalizedNewButtonName.Length -ge 30) {
        [System.Windows.Forms.MessageBox]::Show("Button name cannot exceed 30 characters.")
        return $false
    }

    if ($normalizedNewButtonName -notmatch '^[\w \.,!\?\(\):;/''"@#&%+=\-]+$') {
        [System.Windows.Forms.MessageBox]::Show("Button name contains unsupported characters.")
        return $false
    }

    $buttons = Import-CustomButtons
    $matchedButton = @($buttons.$SectionName) | Where-Object { $_.Text -eq $OldButtonName } | Select-Object -First 1

    if (-not $matchedButton) {
        [System.Windows.Forms.MessageBox]::Show("Could not find the selected button in this section.")
        return $false
    }

    $duplicateButton = @($buttons.$SectionName) |
    Where-Object {
        $_ -ne $matchedButton -and
        -not [string]::IsNullOrWhiteSpace($_.Text) -and
        $_.Text.Trim() -ieq $normalizedNewButtonName
    } |
    Select-Object -First 1

    if ($duplicateButton) {
        [System.Windows.Forms.MessageBox]::Show("A button named '$normalizedNewButtonName' already exists in this section.")
        return $false
    }

    $matchedButton.Text = $normalizedNewButtonName

    Save-CustomButtons $buttons
    [System.Windows.Forms.MessageBox]::Show("Button renamed successfully. Please relaunch the application to see changes.")
    return $true
}

function Invoke-EditMenuSectionRename {
    param(
        [System.Windows.Forms.ComboBox]$SlotCombo,
        [System.Windows.Forms.TextBox]$NewSectionTextBox
    )

    $selectedSlot = Get-EditMenuSelectedSlotKey -SlotCombo $SlotCombo
    if (-not $selectedSlot) {
        [System.Windows.Forms.MessageBox]::Show("Please select a section to rename.")
        return
    }

    $newSectionName = $NewSectionTextBox.Text.Trim()
    if ([string]::IsNullOrEmpty($newSectionName)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a new name for the section.")
        return
    }

    if ($newSectionName.Length -ge 30) {
        [System.Windows.Forms.MessageBox]::Show("Section name cannot exceed 30 characters.")
        return
    }

    if ($newSectionName -notmatch '^[\w \.,!\?\(\):;/''"@#&%+=\-]+$') {
        [System.Windows.Forms.MessageBox]::Show("Section name contains unsupported characters.")
        return
    }

    $conflictingSection = @(Get-EditMenuSectionComboItems) |
    Where-Object {
        $_.SlotKey -ne $selectedSlot -and
        -not [string]::IsNullOrWhiteSpace($_.DisplayName) -and
        $_.DisplayName.Trim() -ieq $newSectionName
    } |
    Select-Object -First 1

    if ($conflictingSection) {
        [System.Windows.Forms.MessageBox]::Show("A section with that name already exists. Please choose a different name.")
        return
    }

    $renamed = Rename-ButtonSection -OldName $selectedSlot -NewName $newSectionName
    if (-not $renamed) {
        return
    }

    Set-EditMenuSectionCombo -SlotCombo $SlotCombo
    foreach ($item in $SlotCombo.Items) {
        if ($item.SlotKey -eq $selectedSlot) {
            $SlotCombo.SelectedItem = $item
            break
        }
    }
    $NewSectionTextBox.Text = ""
    [System.Windows.Forms.MessageBox]::Show("Section renamed successfully. Please relaunch the application to see changes.")

}

function Show-EditButtonMenu {
    param(
        [System.Windows.Forms.Form]$parentForm = $null
    )

    $returnToSettings = $false

    $editButtonForm = New-Object System.Windows.Forms.Form
    $editButtonForm.Text = "Edit Buttons"
    $editButtonForm.Size = New-Object System.Drawing.Size(420, 430)
    $editButtonForm.StartPosition = 'CenterScreen'
    $editButtonForm.FormBorderStyle = 'FixedSingle'
    $editButtonForm.MaximizeBox = $false
    $editButtonForm.ShowIcon = $false

    # If parent form exists and isn't disposed, then editButton form where parent form location was
    if ($ParentForm -and -not $ParentForm.IsDisposed) {
        $editButtonForm.StartPosition = 'Manual'
        $editButtonForm.Location = $ParentForm.Location
    }

    $labelSlot = New-Object System.Windows.Forms.Label
    $labelSlot.Text = "Select Section:"
    $labelSlot.Location = New-Object System.Drawing.Point(15, 20)
    $labelSlot.Size = New-Object System.Drawing.Size(120, 20)
    $labelSlot.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    $comboSlot = New-Object System.Windows.Forms.ComboBox
    $comboSlot.Location = New-Object System.Drawing.Point(140, 20)
    $comboSlot.Size = New-Object System.Drawing.Size(200, 20)
    $comboSlot.DropDownStyle = 'DropDownList'
    $comboSlot.DisplayMember = 'DisplayName'
    $comboSlot.ValueMember = 'SlotKey'

    # Set edit menu section combo items
    Set-EditMenuSectionCombo -SlotCombo $comboSlot

    $labelSectionName2 = New-Object System.Windows.Forms.Label
    $labelSectionName2.Text = "New Section Name:"
    $labelSectionName2.Location = New-Object System.Drawing.Point(15, 60)
    $labelSectionName2.Size = New-Object System.Drawing.Size(120, 20)

    $textBoxNewSectionName = New-Object System.Windows.Forms.TextBox
    $textBoxNewSectionName.Location = New-Object System.Drawing.Point(140, 60)
    $textBoxNewSectionName.Size = New-Object System.Drawing.Size(180, 20)

    # TextBox policies for ctrl+a and alphanumeric input
    Register-TextBoxCtrlA -TextBox $textBoxNewSectionName
    Register-AlphanumericTextBoxPolicy -TextBox $textBoxNewSectionName -MaxLength 30 -AllowSpaces

    $btnRenameSection = New-Object System.Windows.Forms.Button
    $btnRenameSection.Text = "Rename"
    $btnRenameSection.Location = New-Object System.Drawing.Point(330, 55)
    $btnRenameSection.Size = New-Object System.Drawing.Size(60, 28)

    $labelSectionName3 = New-Object System.Windows.Forms.Label
    $labelSectionName3.Text = "Select Button:"
    $labelSectionName3.Location = New-Object System.Drawing.Point(15, 110)
    $labelSectionName3.Size = New-Object System.Drawing.Size(120, 20)
    $labelSectionName3.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    $comboEditButton = New-Object System.Windows.Forms.ComboBox
    $comboEditButton.Location = New-Object System.Drawing.Point(140, 110)
    $comboEditButton.Size = New-Object System.Drawing.Size(200, 20)
    $comboEditButton.DropDownStyle = 'DropDownList'

    $btnEditButton = New-Object System.Windows.Forms.Button
    $btnEditButton.Text = "Rename"
    $btnEditButton.Location = New-Object System.Drawing.Point(330, 145)
    $btnEditButton.Size = New-Object System.Drawing.Size(60, 28)

    $buttonEditNameLabel = New-Object System.Windows.Forms.Label
    $buttonEditNameLabel.Text = "New Button Name:"
    $buttonEditNameLabel.Location = New-Object System.Drawing.Point(15, 150)
    $buttonEditNameLabel.Size = New-Object System.Drawing.Size(120, 20)

    $buttonEditNameTextBox = New-Object System.Windows.Forms.TextBox
    $buttonEditNameTextBox.Location = New-Object System.Drawing.Point(140, 150)
    $buttonEditNameTextBox.Size = New-Object System.Drawing.Size(180, 20)
    Register-TextBoxCtrlA -TextBox $buttonEditNameTextBox
    Register-AlphanumericTextBoxPolicy -TextBox $buttonEditNameTextBox -MaxLength 30 -AllowSpaces

    $textBoxLabel = New-Object System.Windows.Forms.Label
    $textBoxLabel.Text = "Edit Button Text:"
    $textBoxLabel.Location = New-Object System.Drawing.Point(15, 190)
    $textBoxLabel.Size = New-Object System.Drawing.Size(120, 20)
    $textBoxLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    $textBoxSection = New-Object System.Windows.Forms.TextBox
    $textBoxSection.Location = New-Object System.Drawing.Point(15, 210)
    $textBoxSection.Size = New-Object System.Drawing.Size(370, 130)
    $textBoxSection.Multiline = $true
    $textBoxSection.ReadOnly = $true
    $textBoxSection.MaxLength = 10000
    $textBoxSection.ScrollBars = 'Vertical'
    Register-TextBoxCtrlA -TextBox $textBoxSection

    $unlockTextSection = New-Object System.Windows.Forms.Button
    $unlockTextSection.Text = "Edit"
    $unlockTextSection.Location = New-Object System.Drawing.Point(15, 350)
    $unlockTextSection.Size = New-Object System.Drawing.Size(60, 28)

    $saveTextSection = New-Object System.Windows.Forms.Button
    $saveTextSection.Text = "Save"
    $saveTextSection.Location = New-Object System.Drawing.Point(85, 350)
    $saveTextSection.Size = New-Object System.Drawing.Size(60, 28)

    $btnBack = New-Object System.Windows.Forms.Button
    $btnBack.Text = "Back"
    $btnBack.Location = New-Object System.Drawing.Point(325, 350)
    $btnBack.Size = New-Object System.Drawing.Size(60, 28)

    # Clear focus/blue hightlight from combo boxes
    $clearComboFocus = {
        $editButtonForm.ActiveControl = $null
    }

    # Rename section
    $btnRenameSection.Add_Click({
            Invoke-EditMenuSectionRename `
                -SlotCombo $comboSlot `
                -NewSectionTextBox $textBoxNewSectionName
        })
    
    # Update button list when a section is selected
    $comboSlot.Add_SelectedIndexChanged({
            $selectedSlot = Get-EditMenuSelectedSlotKey -SlotCombo $comboSlot

            $textBoxNewSectionName.Text = ""
            Update-EditMenuButtonList -ButtonCombo $comboEditButton -SectionName $selectedSlot
            $textBoxSection.Text = ""
            $textBoxSection.ReadOnly = $true

            & $clearComboFocus
        })

    # Clear focus/blue highlight when leaving the combo box
    $comboSlot.Add_Leave({
            & $clearComboFocus
        })
    
    
    $btnEditButton.Add_Click({
            $selectedSection = Get-EditMenuSelectedSlotKey -SlotCombo $comboSlot
            $selectedButton = [string]$comboEditButton.SelectedItem

            # Set new button name
            $newButtonName = $buttonEditNameTextBox.Text.Trim()

            # If no selection is made 
            if (-not $selectedSection) {
                [System.Windows.Forms.MessageBox]::Show("Please select a section first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            # If button is not selected
            if ([string]::IsNullOrWhiteSpace($selectedButton)) {
                [System.Windows.Forms.MessageBox]::Show("Please select a button first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            # Save the renamed button
            $renamed = Save-RenamedButton -SectionName $selectedSection -OldButtonName $selectedButton -NewButtonName $newButtonName
            if (-not $renamed) {
                return
            }

            # Clear button edit text box and update button list
            $buttonEditNameTextBox.Text = ""
            Update-EditMenuButtonList -ButtonCombo $comboEditButton -SectionName $selectedSection
            $comboEditButton.SelectedIndex = -1
            $textBoxSection.Text = ""
            $textBoxSection.ReadOnly = $true
        })
    
    
    # Unlock text section for editing 
    $unlockTextSection.Add_Click({
            $textBoxSection.ReadOnly = $false
            $textBoxSection.Focus()
            $textBoxSection.SelectionStart = $textBoxSection.TextLength
            $textBoxSection.SelectionLength = 0
        })
    
    # Save edited clipboard text 
    $saveTextSection.Add_Click({
            $selectedSection = Get-EditMenuSelectedSlotKey -SlotCombo $comboSlot
            $selectedButton = [string]$comboEditButton.SelectedItem

            # If no section is selected
            if (-not $selectedSection) {
                [System.Windows.Forms.MessageBox]::Show("Please select a section first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            # If no button is selected
            if ([string]::IsNullOrWhiteSpace($selectedButton)) {
                [System.Windows.Forms.MessageBox]::Show("Please select a button first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            # If new text is empty 
            $newText = $textBoxSection.Text.Trim()
            if ([string]::IsNullOrEmpty($newText)) {
                [System.Windows.Forms.MessageBox]::Show("Button text cannot be empty.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            # Save edited button text for clipboard
            $saved = Save-EditedButtonText -SectionName $selectedSection -ButtonName $selectedButton -NewText $newText
            if (-not $saved) {
                return
            }

            # Update button list in the edit menu
            Update-EditMenuButtonList -ButtonCombo $comboEditButton -SectionName $selectedSection
            $textBoxSection.ReadOnly = $true
        })
    
    # Handle button selection change
    $comboEditButton.Add_SelectedIndexChanged({
            $selectedSection = Get-EditMenuSelectedSlotKey -SlotCombo $comboSlot
            $selectedButton = $comboEditButton.SelectedItem

            # If both a section and a button are selected, update the text box with the button's display text
            if ($selectedSection -and $selectedButton) {
                $matchedBtn = Get-EditMenuMatchedButton -SectionName $selectedSection -ButtonText $selectedButton
                $textBoxSection.Text = Get-EditMenuButtonDisplayText -ButtonData $matchedBtn
                $textBoxSection.ReadOnly = $true
            }

            & $clearComboFocus
        })
    
    $comboEditButton.Add_Leave({
            & $clearComboFocus
        })
    
    $btnBack.Add_Click({
            $returnToSettings = $true
            $editButtonForm.Close()
        })

    $editButtonForm.Add_MouseDown({
            & $clearComboFocus
        })

    $labelSlot.Add_MouseDown({
            & $clearComboFocus
        })

    $labelSectionName2.Add_MouseDown({
            & $clearComboFocus
        })

    $labelSectionName3.Add_MouseDown({
            & $clearComboFocus
        })

    $buttonEditNameLabel.Add_MouseDown({
            & $clearComboFocus
        })

    $textBoxLabel.Add_MouseDown({
            & $clearComboFocus
        })

    $editButtonForm.Controls.AddRange(@(
            $labelSlot,
            $comboSlot,
            $labelSectionName2,
            $textBoxNewSectionName,
            $btnRenameSection,
            $labelSectionName3,
            $comboEditButton,
            $btnEditButton,
            $buttonEditNameLabel,
            $buttonEditNameTextBox,
            $textBoxLabel,
            $textBoxSection,
            $unlockTextSection,
            $saveTextSection,
            $btnBack
        ))

    $editButtonForm.Add_Shown({
            $script:activeForm = $editButtonForm
            & $clearComboFocus
        })

    $editButtonForm.Add_FormClosing({
            if ($ParentForm -and -not $ParentForm.IsDisposed) {
                $ParentForm.Location = $editButtonForm.Location
                $script:activeForm = $ParentForm
                $returnToSettings = $true
            }
        })

    $editButtonForm.ShowDialog()
}
