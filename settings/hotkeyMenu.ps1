$script:HotKeySupportedModifiers = @('None', 'Shift', 'Control', 'Alt', 'Control+Shift', 'Control+Alt', 'Alt+Shift', 'Control+Alt+Shift')
$script:HotKeySupportedKeys = @(
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'Num 0', 'Num 1', 'Num 2', 'Num 3', 'Num 4', 'Num 5', 'Num 6', 'Num 7', 'Num 8', 'Num 9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', 'F1', 'F2', 'F3',
    'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
    '-', '=', '[', ']', '\\', ';', "'", '/', '.', ',', '`', 'Enter',
    'Num /', 'Num *', 'Num -', 'Num +'
)

function Get-HotKeySettingsFilePath {
    # Persist settings under AppData so the selected hotkey survives restarts.
    $appDataFolder = Join-Path $env:APPDATA 'QuickCopy'

    # If the AppData folder for QuickCopy does not exist, create it
    if (-not (Test-Path $appDataFolder)) {
        New-Item -ItemType Directory -Path $appDataFolder | Out-Null
    }

    return Join-Path $appDataFolder 'hotkeySettings.json'
}

# Default hotkey is Shift+T when launching
function New-DefaultHotKeySettings {
    return [PSCustomObject]@{
        Modifier = 'Shift'
        Key      = 'T'
    }
}

function Get-HotKeySettings {
    $hotKeyPath = Get-HotKeySettingsFilePath
    $defaults = New-DefaultHotKeySettings

    # If hotkey settings file does not exist, return the default settings
    if (-not (Test-Path $hotKeyPath)) {
        return $defaults
    }

    try {
        # Load the hotkey settings from the file
        $loaded = Get-Content $hotKeyPath -Raw | ConvertFrom-Json
    }
    catch {
        return $defaults
    }

    # If the loaded settings are not supported, return the default settings
    if (-not ($script:HotKeySupportedModifiers -contains [string]$loaded.Modifier)) {
        return $defaults
    }

    # If the loaded key is not supported, return the default settings
    if (-not ($script:HotKeySupportedKeys -contains [string]$loaded.Key)) {
        return $defaults
    }

    return [PSCustomObject]@{
        Modifier = [string]$loaded.Modifier
        Key      = [string]$loaded.Key
    }
}

function Save-HotKeySettings {
    param(
        [Parameter(Mandatory)] [string]$Modifier,
        [Parameter(Mandatory)] [string]$Key
    )

    # If the provided modifier or key is not supported
    if (-not ($script:HotKeySupportedModifiers -contains $Modifier)) {
        throw "Unsupported hotkey modifier: $Modifier"
    }

    # If the provided key is not supported
    if (-not ($script:HotKeySupportedKeys -contains $Key)) {
        throw "Unsupported hotkey key: $Key"
    }

    $payload = [PSCustomObject]@{
        Modifier = $Modifier
        Key      = $Key
    }
    
    # Save the hotkey settings to the file
    $payload | ConvertTo-Json | Set-Content (Get-HotKeySettingsFilePath)
}

# Converts hotkey settings to Win32 format for RegisterHotKey
function Convert-HotKeySettingsToWin32 {
    param(
        [Parameter(Mandatory)] $Settings
    )

    # RegisterHotKey expects a modifier bitmask plus a virtual key code.
    $modifierMap = @{
        'None'          = [uint32]0x0000
        'Alt'           = [uint32]0x0001
        'Control'       = [uint32]0x0002
        'Shift'         = [uint32]0x0004
        'Control+Shift' = [uint32](0x0002 -bor 0x0004)
        'Control+Alt'   = [uint32](0x0002 -bor 0x0001)
        'Alt+Shift'     = [uint32](0x0001 -bor 0x0004)
        'Control+Alt+Shift' = [uint32](0x0002 -bor 0x0001 -bor 0x0004)
    }

    # Convert the hotkey settings to Win32 format
    $modText = [string]$Settings.Modifier
    $keyText = [string]$Settings.Key
    $enumKeyText = Convert-HotKeyTextToWinFormsKeyName -KeyText $keyText

    # Validate the modifier
    if (-not $modifierMap.ContainsKey($modText)) {
        throw "Unsupported hotkey modifier: $modText"
    }

    try {
        # Validate the key
        $keyEnum = [System.Windows.Forms.Keys]::$enumKeyText
    }
    catch {
        throw "Unsupported hotkey key: $keyText"
    }

    return [PSCustomObject]@{
        ModifierMask = [uint32]$modifierMap[$modText]
        VirtualKey   = [uint32]$keyEnum
        DisplayText  = "$modText+$keyText"
    }
}

function Format-HotKeyDisplayText {
    param(
        [Parameter(Mandatory)] [string]$Modifier,
        [Parameter(Mandatory)] [string]$Key
    )

    if ($Modifier -eq 'None') {
        return $Key
    }

    return "$Modifier+$Key"
}

function Convert-HotKeyTextToWinFormsKeyName {
    param(
        [Parameter(Mandatory)] [string]$KeyText
    )

    # If the key is a single digit, convert it to the corresponding D0-D9 enum member
    if ($KeyText -match '^[0-9]$') {
        return "D$KeyText"
    }

    # Translate display labelsto WinForms enum member names.
    $specialKeyMap = @{
        'Num 0' = 'NumPad0'
        'Num 1' = 'NumPad1'
        'Num 2' = 'NumPad2'
        'Num 3' = 'NumPad3'
        'Num 4' = 'NumPad4'
        'Num 5' = 'NumPad5'
        'Num 6' = 'NumPad6'
        'Num 7' = 'NumPad7'
        'Num 8' = 'NumPad8'
        'Num 9' = 'NumPad9'
        '-'     = 'OemMinus'
        '='     = 'Oemplus'
        '['     = 'OemOpenBrackets'
        ']'     = 'Oem6'
        '\\'    = 'Oem5'
        ';'     = 'Oem1'
        "'"     = 'OemQuotes'
        '/'     = 'OemQuestion'
        '.'     = 'OemPeriod'
        ','     = 'Oemcomma'
        '`'     = 'Oemtilde'
        'Enter' = 'Enter'
        'Num /' = 'Divide'
        'Num *' = 'Multiply'
        'Num -' = 'Subtract'
        'Num +' = 'Add'
    }

    # If the key is in the special key map, return the corresponding WinForms enum member name
    if ($specialKeyMap.ContainsKey($KeyText)) {
        return $specialKeyMap[$KeyText]
    }

    return $KeyText
}

function Get-HotKeyModifierTextFromFlags {
    param(
        [bool]$Control,
        [bool]$Alt,
        [bool]$Shift
    )

    $parts = @()

    if ($Control) {
        $parts += 'Control'
    }

    if ($Alt) {
        $parts += 'Alt'
    }

    if ($Shift) {
        $parts += 'Shift'
    }

    if ($parts.Count -eq 0) {
        return 'None'
    }

    return [string]::Join('+', $parts)
}

function Convert-WinFormsKeyToHotKeyText {
    param(
        [Parameter(Mandatory)] [System.Windows.Forms.Keys]$KeyCode
    )

    # Convert WinForms key enum to hotkey text
    $keyName = [string]$KeyCode

    # If key is a digit (D0-D9), convert it to the corresponding number
    if ($keyName -match '^D([0-9])$') {
        return $Matches[1]
    }

    # If key is a numpad digit (NumPad0-NumPad9), convert it to the corresponding "Num X" format
    if ($keyName -match '^NumPad([0-9])$') {
        return "Num $($Matches[1])"
    }

    # If key is a letter (A-Z), return it as is
    if ($keyName -match '^[A-Z]$') {
        return $keyName
    }

    # If key is a function key (F1-F12), return it as is
    if ($keyName -match '^F([1-9]|1[0-2])$') {
        return $keyName
    }

    # Reverse translation for key capture: enum name -> user-facing label.
    $specialKeyMap = @{
        'NumPad0'         = 'Num 0'
        'NumPad1'         = 'Num 1'
        'NumPad2'         = 'Num 2'
        'NumPad3'         = 'Num 3'
        'NumPad4'         = 'Num 4'
        'NumPad5'         = 'Num 5'
        'NumPad6'         = 'Num 6'
        'NumPad7'         = 'Num 7'
        'NumPad8'         = 'Num 8'
        'NumPad9'         = 'Num 9'
        'OemMinus'        = '-'
        'Oemplus'         = '='
        'OemOpenBrackets' = '['
        'Oem6'            = ']'
        'Oem5'            = '\\'
        'Oem1'            = ';'
        'OemQuotes'       = "'"
        'OemQuestion'     = '/'
        'OemPeriod'       = '.'
        'Oemcomma'        = ','
        'Oemtilde'        = '`'
        'Enter'           = 'Enter'
        'Return'          = 'Enter'
        'Divide'          = 'Num /'
        'Multiply'        = 'Num *'
        'Subtract'        = 'Num -'
        'Add'             = 'Num +'
    }

    if ($specialKeyMap.ContainsKey($keyName)) {
        return $specialKeyMap[$keyName]
    }

    return $null
}

function Show-HotKeySettingsMenu {
    param(
        [Parameter(Mandatory)] [System.Windows.Forms.Form]$ParentForm
    )

    # Retrieve current hotkey settings
    $settings = Get-HotKeySettings
    $selectedHotKey = [PSCustomObject]@{
        Modifier = [string]$settings.Modifier
        Key      = [string]$settings.Key
    }

    # Initialize capture state
    $captureState = [PSCustomObject]@{
        PendingModifier = $null
        PendingKey      = $null
    }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Hotkey Settings"
    $dialog.Size = New-Object System.Drawing.Size(420, 250)
    $dialog.StartPosition = 'Manual'
    $dialog.Location = $ParentForm.Location
    $dialog.FormBorderStyle = 'FixedSingle'
    $dialog.MaximizeBox = $false
    $dialog.ShowIcon = $false

    $lblCapture = New-Object System.Windows.Forms.Label
    $lblCapture.Text = 'Hotkey Combination Below:'
    $lblCapture.Location = New-Object System.Drawing.Point(15, 20)
    $lblCapture.Size = New-Object System.Drawing.Size(300, 20)
    $lblCapture.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    $txtHotKeyCapture = New-Object System.Windows.Forms.TextBox
    $txtHotKeyCapture.Location = New-Object System.Drawing.Point(18, 50)
    $txtHotKeyCapture.Size = New-Object System.Drawing.Size(370, 24)
    $txtHotKeyCapture.ReadOnly = $true
    $txtHotKeyCapture.ShortcutsEnabled = $false

    # Set initial text for the hotkey capture textbox. Depends on if there were already saved hotkey settings
    $txtHotKeyCapture.Text = (Format-HotKeyDisplayText -Modifier $selectedHotKey.Modifier -Key $selectedHotKey.Key)

    $lblHelp = New-Object System.Windows.Forms.Label
    $lblHelp.Text = "Hold modifiers, press the key, then release all keys to save the hotkey.`nNOTE: Some keys are blocked due to Windows shortcuts (e.g., Alt+Tab, Ctrl+Alt+Del)."
    $lblHelp.Location = New-Object System.Drawing.Point(18, 85)
    $lblHelp.Size = New-Object System.Drawing.Size(370, 35)

    # Handle focus events to ensure the cursor is at the end of the text as well as blue highlight removal
    $txtHotKeyCapture.Add_Enter({
            $txtHotKeyCapture.SelectionStart = $txtHotKeyCapture.TextLength
            $txtHotKeyCapture.SelectionLength = 0
        }.GetNewClosure())

    $txtHotKeyCapture.Add_MouseDown({
            $txtHotKeyCapture.SelectionStart = $txtHotKeyCapture.TextLength
            $txtHotKeyCapture.SelectionLength = 0
        }.GetNewClosure())

    $txtHotKeyCapture.Add_Leave({
            $txtHotKeyCapture.Text = (Format-HotKeyDisplayText -Modifier $selectedHotKey.Modifier -Key $selectedHotKey.Key)
        }.GetNewClosure())

    # Handle key events to capture hotkey combinations in real time
    $txtHotKeyCapture.Add_KeyDown({
            param($sender, $e)

            $e.Handled = $true
            $e.SuppressKeyPress = $true

            # Track current modifier state + latest key; final selection is committed on KeyUp.
            $shiftPressed = $e.Shift -or $e.KeyCode -eq [System.Windows.Forms.Keys]::ShiftKey
            $modifierText = Get-HotKeyModifierTextFromFlags -Control:$e.Control -Alt:$e.Alt -Shift:$shiftPressed
            $capturedKey = Convert-WinFormsKeyToHotKeyText -KeyCode $e.KeyCode

            # If a valid key was captured, update the pending state and display the combination
            if ($capturedKey) {
                $captureState.PendingModifier = $modifierText
                $captureState.PendingKey = $capturedKey
                $sender.Text = if ($modifierText) {
                    Format-HotKeyDisplayText -Modifier $modifierText -Key $capturedKey
                }
                else {
                    $capturedKey
                }
                return
            }

            # If only modifiers are pressed, update the pending state and display the combination with periods
            if ($modifierText -and $modifierText -ne 'None') {
                $captureState.PendingModifier = $modifierText
                $captureState.PendingKey = $null
                $sender.Text = "$modifierText+..."
                return
            }
            
            # If an unsupported key is pressed, display a message to the user
            if ($e.KeyCode -notin @([System.Windows.Forms.Keys]::ControlKey, [System.Windows.Forms.Keys]::Menu, [System.Windows.Forms.Keys]::ShiftKey)) {
                $sender.Text = 'Unsupported key. Use A-Z, 0-9, F1-F12, Numpad, Punctuation, etc.'
            }
        }.GetNewClosure())

    $txtHotKeyCapture.Add_KeyUp({
            param($sender, $e)

            $e.Handled = $true
            $e.SuppressKeyPress = $true

            # Commit only after all modifiers are released to avoid partial combinations
            if ([System.Windows.Forms.Control]::ModifierKeys -ne [System.Windows.Forms.Keys]::None) {
                return
            }

            # If a valid hotkey combination was captured, commit it
            if ($captureState.PendingModifier -and $captureState.PendingKey) {
                $selectedHotKey.Modifier = $captureState.PendingModifier
                $selectedHotKey.Key = $captureState.PendingKey
                $sender.Text = Format-HotKeyDisplayText -Modifier $selectedHotKey.Modifier -Key $selectedHotKey.Key
            }
            # If no valid hotkey combination was captured, revert to the previous selection
            else {
                $sender.Text = Format-HotKeyDisplayText -Modifier $selectedHotKey.Modifier -Key $selectedHotKey.Key
            }

            $captureState.PendingModifier = $null
            $captureState.PendingKey = $null
        }.GetNewClosure())

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save"
    $btnSave.Location = New-Object System.Drawing.Point(90, 150)
    $btnSave.Size = New-Object System.Drawing.Size(100, 30)
    $btnSave.Add_Click({
            if ([string]::IsNullOrWhiteSpace($selectedHotKey.Key)) {
                [System.Windows.Forms.MessageBox]::Show('Please capture a hotkey with a supported key.', 'Hotkey Settings', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                return
            }

            try {
                # Save the hotkey settings to the configuration
                Save-HotKeySettings -Modifier $selectedHotKey.Modifier -Key $selectedHotKey.Key

                # Try reloading the global registration so users do not lose the new shortcut
                if (Get-Command -Name Update-GlobalHotKeyRegistration -ErrorAction SilentlyContinue) {
                    $applied = Update-GlobalHotKeyRegistration
                    # If the hotkey could not be registered
                    if (-not $applied) {
                        [System.Windows.Forms.MessageBox]::Show('Settings saved, but the hotkey could not be registered. Please relaunch the application and try again.', 'Hotkey Settings', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                    }
                }
                [System.Windows.Forms.MessageBox]::Show('Hotkey updated successfully. Please relaunch the application.', 'Hotkey Settings', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to save hotkey settings. $_", 'Hotkey Settings', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            }
        })

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Back"
    $btnCancel.Location = New-Object System.Drawing.Point(220, 150)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 30)
    $btnCancel.Add_Click({ $dialog.Close() })

    $dialog.Controls.AddRange(@($lblCapture, $txtHotKeyCapture, $lblHelp, $btnSave, $btnCancel))
    $dialog.Add_Shown({ $txtHotKeyCapture.Focus() }.GetNewClosure())
    $dialog.ShowDialog()
}
