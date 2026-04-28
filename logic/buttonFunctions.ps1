function New-MenuButton {
    param($text, $location, $clickAction)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = New-Object System.Drawing.Size(120, 40)
    $btn.Location = $location
    $btn.Font = New-Object System.Drawing.Font("Arial", 8)
    $btn.Add_Click($clickAction)
    return $btn
}

<#
Creates real-time display in a RichTextBox control.

#>

function New-RealTimeDisplay {
    param($text, $location)
    $richTextBox = New-Object System.Windows.Forms.RichTextBox
    $richTextBox.Text = $text
    $richTextBox.Size = New-Object System.Drawing.Size(260, 120)
    $richTextBox.Location = $location
    $richTextBox.ReadOnly = $true
    $richTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    return $richTextBox
}

<#
Checks if the specified file exists before executing the provided action.
If the file exists, the specified action is executed. Otherwise, an error message is displayed and the form is closed.

#>

function Invoke-WithFileCheck {
    param($filePath, $action, $errorMessage)
    if (Test-Path $filePath) {
        & $action
    }
    else {
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $form.Close()
    }
}

<#
Checks if the current user has administrator privileges, if not then displays a warning message and closes the form.
Application doesn't need administrator privileges to run, but certain actions may require elevated permissions.

#>

function Invoke-Administrator {
    param($action)
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        & $action
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("This action requires administrator privileges. Please run the application as an administrator.", "Permission Denied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        $form.Close()
    }
}

<#
Creates a new label with specified text and position that's being called from clipboard\clipboardGUI.ps1
for default 'no buttons to display' message. 

#>

function New-Label {
    param(
        [string] $text,
        [int] $x,
        [int] $y
    )

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Location = New-Object System.Drawing.Point($x, $y)
    $lbl.AutoSize = $true
    return $lbl
}

<#

This function launches the button loader for a specific section, creating buttons based on the provided source buttons and layout configuration.
It takes the section name, source buttons, and layout configuration as input and generates the corresponding buttons, adding them to the provided Buttons reference.
The function also supports specifying the maximum number of buttons to display, the positions for the buttons in different layouts, and the spacing between rows. 
It ensures that only valid buttons with non-empty text are displayed and provides warnings if the number of buttons exceeds the maximum allowed.

#>

function Launch-ButtonLoader {
    param(
        [Parameter(Mandatory)] [string] $Section,
        [Parameter(Mandatory)] [array] $SourceButtons,
        [Parameter(Mandatory)] [ref] $Buttons,
        # Layout configuration for even/odd columns and single column
        [ValidateSet("TwoColumn", "SingleColumn")] [string] $Layout = "TwoColumn",
        [int] $MaxButtons = 10,
        [int] $XPosLeft = 10,
        [int] $XPosRight = 150,
        [int] $XPosSingle = 10,
        [int] $YStart = 30,
        [int] $RowSpacing = 50
    )

    # Filter out buttons with empty or whitespace text
    $validButtons = @($SourceButtons | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Text) })

    # Calculate the total number of buttons and the number of buttons to display
    $totalButtonCount = $validButtons.Count

    # Determine the number of buttons to display based on the max allowed
    $displayedCount = [Math]::Min($totalButtonCount, $MaxButtons)
    $currentY = $YStart
    $projectRoot = if (-not [string]::IsNullOrWhiteSpace($script:AppRoot)) {
        $script:AppRoot
    }
    elseif (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        Split-Path $PSScriptRoot -Parent
    }
    else {
        ''
    }

    # If the total number of buttons exceeds the maximum allowed edge case
    if ($totalButtonCount -gt $MaxButtons) {
        [System.Windows.Forms.MessageBox]::Show("Warning: $totalButtonCount buttons found in section '$Section', but only $MaxButtons will be displayed. Please ensure your customButtons.json is configured correctly.", "Button Limit Exceeded", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }

    # Loop through the buttons to create and position them
    for ($index = 0; $index -lt $displayedCount; $index++) {
        $custom = $validButtons[$index]
        $customText = $custom.Text
        $customPrompt = $custom.Command
        $customFilePath = $custom.FilePath

        # If layout is TwoColumn, alternate between left and right positions for even/odd buttons
        $buttonX = if ($Layout -eq "TwoColumn") {
            if ($index % 2 -eq 0) { $XPosLeft } else { $XPosRight }
        }
        else {
            $XPosSingle
        }

        $buttonY = $currentY

        # Create the button and assign the clipboard content based on the file path or command
        $btn = New-MenuButton $customText (New-Object System.Drawing.Point($buttonX, $buttonY)) {
            # If not empty, use the file path to get the content and set it to the clipboard
            $customFilePathText = if ($null -eq $customFilePath) { '' } else { [string]$customFilePath }

            if (-not [string]::IsNullOrWhiteSpace($customFilePathText)) {
                $resolvedPath = if ([System.IO.Path]::IsPathRooted($customFilePathText)) {
                    $customFilePathText
                }
                # If the file path is relative, combine it with the project root to get the full path
                elseif (-not [string]::IsNullOrWhiteSpace($projectRoot)) {
                    Join-Path $projectRoot $customFilePathText
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show("FilePath for '$customText' is relative, but the app root could not be resolved. Please use an absolute path or relaunch the app.", "Configuration Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    return
                }
                # Check if the resolved path exists, read its content, and set it to the clipboard
                if (Test-Path $resolvedPath) {
                    $text = Get-Content $resolvedPath -Raw
                    [System.Windows.Forms.Clipboard]::SetText($text)
                }
                # Default critical error if the file does not exist at the resolved path
                else {
                    [System.Windows.Forms.MessageBox]::Show("Critical Error: File not found at $resolvedPath. Please update customButtons.json.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
            # If the file path is empty but a command is provided, set the command to the clipboard
            elseif (-not [string]::IsNullOrWhiteSpace($customPrompt)) {
                [System.Windows.Forms.Clipboard]::SetText($customPrompt)
            }
            # Warning message for missing command and file path
            else {
                [System.Windows.Forms.MessageBox]::Show("No Command or FilePath configured for '$customText' in customButtons.json.", "Configuration Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
        }.GetNewClosure()

        $Buttons.Value += $btn

        # Update the Y position for next button based on the layout and current index
        if ($Layout -eq "TwoColumn") {
            if ($index % 2 -eq 1) {
                $currentY += $RowSpacing
            }
        }
        else {
            $currentY += $RowSpacing
        }
    }

    # Adjust Y position if layout is TwoColumn and the number of displayed buttons is odd
    if ($Layout -eq "TwoColumn" -and $displayedCount -gt 0 -and $displayedCount % 2 -eq 1) {
        $currentY += $RowSpacing
    }

    return [PSCustomObject]@{
        TotalCount     = $totalButtonCount
        DisplayedCount = $displayedCount
        NextY          = $currentY
    }
}
