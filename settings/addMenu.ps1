function Get-SectionHeaderForSlot {
    param(
        [string]$SlotName
    )

    if ([string]::IsNullOrWhiteSpace($SlotName)) {
        return ""
    }

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

function Get-AddMenuSectionComboItems {
    $items = @()

    foreach ($slot in $script:CustomButtonSections) {
        $header = Get-SectionHeaderForSlot -SlotName $slot
        $display = if ([string]::IsNullOrWhiteSpace($header)) { $slot } else { $header }

        $items += [pscustomobject]@{
            SlotKey     = $slot
            DisplayName = $display
        }
    }

    return $items
}

function Set-AddMenuSectionCombo {
    param(
        [System.Windows.Forms.ComboBox]$SlotCombo
    )

    $SlotCombo.Items.Clear()
    foreach ($item in @(Get-AddMenuSectionComboItems)) {
        [void]$SlotCombo.Items.Add($item)
    }
}

function Import-ButtonContentFromFile {
    param(
        [System.Windows.Forms.TextBox]$ContentTextBox
    )

    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $openFileDialog.Multiselect = $false

    if ($openFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    $loadedText = Get-Content $openFileDialog.FileName -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($loadedText)) {
        [System.Windows.Forms.MessageBox]::Show("The selected file is empty or could not be read.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $ContentTextBox.Text = $loadedText
    $script:UploadedTxtPath = $openFileDialog.FileName
}

function Add-NewCustomButton {
    param(
        [string]$SelectedSlot,
        [string]$SectionHeader,
        [string]$ButtonName,
        [string]$ContentText,
        [string]$FilePath
    )

    # Helper function to show validation error
    function Show-ValidationError {
        param([string]$Message)
        [System.Windows.Forms.MessageBox]::Show($Message, "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }

    # Validate required inputs
    if ([string]::IsNullOrWhiteSpace($SelectedSlot)) {
        Show-ValidationError "Please select a custom slot (Custom1..Custom10)."
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($ButtonName)) {
        Show-ValidationError "Please type a name for the button."
        return $false
    }

    if ($ButtonName.Length -ge 30) {
        Show-ValidationError "Button name cannot exceed 30 characters."
        return $false
    }

    if ($ButtonName -notmatch '^[\w \.,!\?\(\):;/''"@#&%+=\-]+$') {
        Show-ValidationError "Button name contains unsupported characters."
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($SectionHeader)) {
        Show-ValidationError "Section header is required."
        return $false
    }

    $hasTypedText = -not [string]::IsNullOrWhiteSpace($ContentText)
    $hasFile = -not [string]::IsNullOrWhiteSpace($FilePath)

    if (-not ($hasTypedText -or $hasFile)) {
        Show-ValidationError "Please type content or upload a .txt file."
        return $false
    }

    $buttons = Import-CustomButtons

    # Check for duplicate button name
    $duplicateButton = @($buttons.$SelectedSlot) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Text) -and $_.Text.Trim() -ieq $ButtonName } |
    Select-Object -First 1

    if ($duplicateButton) {
        Show-ValidationError "A button named '$ButtonName' already exists in this section."
        return $false
    }

    # Check max buttons per slot
    if (@($buttons.$SelectedSlot).Count -ge 10) {
        Show-ValidationError "Maximum 10 buttons per slot."
        return $false
    }

    # Create and add new button
    $newButton = [pscustomobject]@{
        'Section Header' = $SectionHeader
        Text             = $ButtonName
        Command          = $(if ($hasTypedText) { $ContentText } else { "" })
    }

    if ($hasFile) {
        $newButton | Add-Member -MemberType NoteProperty -Name FilePath -Value $FilePath
    }

    $buttons.$SelectedSlot += $newButton

    Save-CustomButtons $buttons
    [System.Windows.Forms.MessageBox]::Show("Custom button added successfully.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    return $true
}

function Show-AddButtonMenu {
    param(
        [System.Windows.Forms.Form]$ParentForm = $null
    )

    $returnToSettings = $false
    $script:UploadedTxtPath = $null

    $addButtonForm = New-Object System.Windows.Forms.Form
    $addButtonForm.Text = "Add Custom Button"
    $addButtonForm.Size = New-Object System.Drawing.Size(400, 340)
    $addButtonForm.StartPosition = 'CenterScreen'
    $addButtonForm.FormBorderStyle = 'FixedSingle'
    $addButtonForm.MaximizeBox = $false
    $addButtonForm.ShowIcon = $false

    # Position the add button form relative to the parent form if provided
    if ($ParentForm -and -not $ParentForm.IsDisposed) {
        $addButtonForm.StartPosition = 'Manual'
        $addButtonForm.Location = $ParentForm.Location
    }

    # Create and configure label and combo for slot selection
    $labelSlot = New-Object System.Windows.Forms.Label
    $labelSlot.Text = "Select Section:"
    $labelSlot.Location = New-Object System.Drawing.Point(15, 20)
    $labelSlot.Size = New-Object System.Drawing.Size(120, 20)
    $labelSlot.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    $comboSlot = New-Object System.Windows.Forms.ComboBox
    $comboSlot.Location = New-Object System.Drawing.Point(140, 20)
    $comboSlot.Size = New-Object System.Drawing.Size(180, 20)
    $comboSlot.DropDownStyle = 'DropDownList'
    $comboSlot.DisplayMember = 'DisplayName'
    $comboSlot.ValueMember = 'SlotKey'

    # Populate the combo box with available sections
    Set-AddMenuSectionCombo -SlotCombo $comboSlot

    # Create and configure button name label and textbox
    $labelButtonName = New-Object System.Windows.Forms.Label
    $labelButtonName.Text = "Button Name:"
    $labelButtonName.Location = New-Object System.Drawing.Point(15, 60)
    $labelButtonName.Size = New-Object System.Drawing.Size(100, 20)

    $textBoxButtonName = New-Object System.Windows.Forms.TextBox
    $textBoxButtonName.Location = New-Object System.Drawing.Point(120, 60)
    $textBoxButtonName.Size = New-Object System.Drawing.Size(200, 20)

    # Apply textbox policies from logic\textBoxPolicies.ps1
    Register-TextBoxCtrlA -TextBox $textBoxButtonName
    Register-AlphanumericTextBoxPolicy -TextBox $textBoxButtonName -MaxLength 30 -AllowSpaces

    # Create and configure content label and textbox
    $labelContent = New-Object System.Windows.Forms.Label
    $labelContent.Text = "Text (Type or Upload):"
    $labelContent.Location = New-Object System.Drawing.Point(15, 100)
    $labelContent.Size = New-Object System.Drawing.Size(160, 20)

    $textBoxContent = New-Object System.Windows.Forms.TextBox
    $textBoxContent.Location = New-Object System.Drawing.Point(15, 120)
    $textBoxContent.Size = New-Object System.Drawing.Size(350, 130)
    $textBoxContent.Multiline = $true
    $textBoxContent.ScrollBars = 'Vertical'
    Register-TextBoxCtrlA -TextBox $textBoxContent

    # Create buttons
    $btnUploadTxt = New-Object System.Windows.Forms.Button
    $btnUploadTxt.Text = "Upload"
    $btnUploadTxt.Location = New-Object System.Drawing.Point(85, 260)
    $btnUploadTxt.Size = New-Object System.Drawing.Size(60, 28)

    $btnAddButton = New-Object System.Windows.Forms.Button
    $btnAddButton.Text = "Add"
    $btnAddButton.Location = New-Object System.Drawing.Point(15, 260)
    $btnAddButton.Size = New-Object System.Drawing.Size(60, 28)

    $btnBack = New-Object System.Windows.Forms.Button
    $btnBack.Text = "Back"
    $btnBack.Location = New-Object System.Drawing.Point(305, 260)
    $btnBack.Size = New-Object System.Drawing.Size(60, 28)

    # Helper to clear focus (removes blue highlight from combo box)
    $clearComboFocus = {
        $addButtonForm.ActiveControl = $null
    }

    # Helper to register focus-clearing events on controls
    $registerFocusClear = {
        param($control)
        $control.Add_MouseDown({ & $clearComboFocus })
    }

    # Register upload button click event
    $btnUploadTxt.Add_Click({
            Import-ButtonContentFromFile -ContentTextBox $textBoxContent
        })

    # Remove focus from combo when selection changes or leaves
    $comboSlot.Add_SelectedIndexChanged({ & $clearComboFocus })
    $comboSlot.Add_Leave({ & $clearComboFocus })

    # Clear focus when form or labels are clicked
    $addButtonForm.Add_MouseDown({ & $clearComboFocus })
    & $registerFocusClear -control $labelSlot
    & $registerFocusClear -control $labelButtonName
    & $registerFocusClear -control $labelContent

    # Add button click event
    $btnAddButton.Add_Click({
            $selectedSlot = [string]$comboSlot.SelectedItem.SlotKey
            $sectionHeader = Get-SectionHeaderForSlot -SlotName $selectedSlot

            # If the section header is null or whitespace, use the selected slot as the section header
            if ([string]::IsNullOrWhiteSpace($sectionHeader)) {
                $sectionHeader = [string]$selectedSlot
            }
            
            # Pass the collected information to add button
            $added = Add-NewCustomButton `
                -SelectedSlot $selectedSlot `
                -SectionHeader $sectionHeader `
                -ButtonName $textBoxButtonName.Text.Trim() `
                -ContentText $textBoxContent.Text `
                -FilePath $script:UploadedTxtPath

            # If the button was not added successfully, exit the function
            if (-not $added) {
                return
            }

            # Clear the input fields and reset the uploaded file path once the button is added successfully
            $textBoxButtonName.Text = ""
            $textBoxContent.Text = ""
            $script:UploadedTxtPath = $null
        })

    # Back button click event
    $btnBack.Add_Click({
            $returnToSettings = $true
            $addButtonForm.Close()
        })

    # Add controls to form
    $addButtonForm.Controls.AddRange(@(
            $labelSlot,
            $comboSlot,
            $labelButtonName,
            $textBoxButtonName,
            $labelContent,
            $textBoxContent,
            $btnUploadTxt,
            $btnAddButton,
            $btnBack
        ))

    # Form shown and closing events
    $addButtonForm.Add_Shown({
            $script:activeForm = $addButtonForm
            & $clearComboFocus
        })

    $addButtonForm.Add_FormClosing({
            if ($ParentForm -and -not $ParentForm.IsDisposed) {
                $ParentForm.Location = $addButtonForm.Location
                $script:activeForm = $ParentForm
                $returnToSettings = $true
            }
        })

    $addButtonForm.ShowDialog()
}