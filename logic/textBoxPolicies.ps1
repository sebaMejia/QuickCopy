# General function to register Ctrl+A behavior for a TextBox
function Register-TextBoxCtrlA {
    param(
        [System.Windows.Forms.TextBox]$TextBox
    )
    
    $TextBox.Add_KeyDown({
            param($sender, $e)

            if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::A) {
                $sender.SelectAll()
                $e.Handled = $true
                $e.SuppressKeyPress = $true
            }
        })
}

# Function to register alphanumeric TextBox policy
function Register-AlphanumericTextBoxPolicy {
    param(
        [System.Windows.Forms.TextBox]$TextBox,
        [int]$MaxLength = 40,
        [switch]$AllowSpaces
    )

    $TextBox.MaxLength = $MaxLength
    # Allow common reply punctuation and URL symbols
    $invalidPattern = if ($AllowSpaces) { '[^\w \.,!\?\(\):;/''"@#&%+=\-]' } else { '[^\w\.,!\?\(\):;/''"@#&%+=\-]' }

    $keyPressHandler = {
        param($control, $e)
        # Handle key press events for alphanumeric input
        if ([char]::IsControl($e.KeyChar)) {
            return
        }
        # If key pressed matches invalid pattern, prevent it from being entered 
        if ([regex]::IsMatch([string]$e.KeyChar, $invalidPattern)) {
            $e.Handled = $true
        }
    }.GetNewClosure()

    # Handle text changed events for alphanumeric input
    $textChangedHandler = {
        param($control, $e)

        # Remove invalid characters from the text
        $original = $control.Text
        $sanitized = [regex]::Replace($original, $invalidPattern, '')

        # If text exceeds the maximum length, truncate it
        if ($sanitized.Length -gt $control.MaxLength) {
            $sanitized = $sanitized.Substring(0, $control.MaxLength)
        }

        # If filtered text differs from the original, update the TextBox
        if ($sanitized -ne $original) {
            $cursor = $control.SelectionStart
            $control.Text = $sanitized
            $control.SelectionStart = [Math]::Min($cursor, $control.TextLength)
        }
    }.GetNewClosure()
    
    $TextBox.Add_KeyPress($keyPressHandler)
    $TextBox.Add_TextChanged($textChangedHandler)
}
