if (-not ("Win32HotKey" -as [type])) {
    # C# interop: wraps RegisterHotKey/UnregisterHotKey and raises an event when WM_HOTKEY is received.
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class Win32HotKey
{
    // Registers a global hotkey with the specified modifier and virtual key
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    // Unregisters a global hotkey
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}

public class GlobalHotKeyFilter : IMessageFilter
{
    // Identifier for the hotkey
    public int HotKeyId { get; set; }
    public event EventHandler HotKeyPressed;

    // Filters messages to detect the registered global hotkey
    public bool PreFilterMessage(ref Message m)
    {
        // If message is hotkey message and the hotkey ID matches, raise the HotKeyPressed event
        if (m.Msg == 0x0312 && m.WParam.ToInt32() == HotKeyId)
        {
            if (HotKeyPressed != null)
                HotKeyPressed(this, EventArgs.Empty);
            return true;
        }
        return false;
    }
}
"@ -ReferencedAssemblies "System.Windows.Forms"
}

# C# interop that wraps double-pressing Ctrl key to go back from a form or dialog
# If the BackNavFilter type is not available, define it
if (-not ("BackNavFilter" -as [type])) {
Add-Type -TypeDefinition @"
using System;
using System.Windows.Forms;

public class BackNavFilter : IMessageFilter
{
    // Nonsystem key message identifier
    private const int WM_KEYDOWN = 0x0100;

    // Ctrl key
    private const int VK_CONTROL = 0x11;

    // Time in between two Ctrl key presses
    private const double DoublePressMsThreshold = 400;

    // Define time of last Ctrl key press
    private DateTime _lastCtrlPress = DateTime.MinValue;

    public event EventHandler BackNavPressed;

    public bool PreFilterMessage(ref Message m)
    {
        // If the message is a key down event and the key is Ctrl
        if (m.Msg == WM_KEYDOWN && m.WParam.ToInt32() == VK_CONTROL)
        {
            // Calculate time elapsed since last Ctrl key press
            DateTime now = DateTime.Now;
            double elapsed = (now - _lastCtrlPress).TotalMilliseconds;

            // If the time elapsed since the last Ctrl key press is within the threshold, trigger the BackNavPressed event
            if (elapsed <= DoublePressMsThreshold)
            {
                // Reset the last Ctrl key press time to avoid multiple triggers
                _lastCtrlPress = DateTime.MinValue;
                
                // Raise the BackNavPressed event
                if (BackNavPressed != null)
                    BackNavPressed(this, EventArgs.Empty);
                return true;
            }

            _lastCtrlPress = now;
        }

        return false;
    }
}
"@ -ReferencedAssemblies "System.Windows.Forms"
}

# 9001 identifier for the global hotkey
$script:globalHotKeyId = 9001
$script:globalHotKeyRegistered = $false

# Shift key
$script:globalHotKeyModifierMask = [uint32]0x0004

# T key
$script:globalHotKeyVirtualKey = [uint32]0x54
$script:globalHotKeyDisplayText = 'Shift+T'

function Resolve-ConfiguredGlobalHotKey {
    # Fallback used when settings helpers are unavailable or settings cannot be parsed
    $default = [PSCustomObject]@{
        ModifierMask = [uint32]0x0004
        VirtualKey   = [uint32]0x54
        DisplayText  = 'Shift+T'
    }

    # If no settings helpers are available, return the default hotkey
    if (-not (Get-Command -Name Get-HotKeySettings -ErrorAction SilentlyContinue)) {
        return $default
    }

    # If the conversion helper is not available, return the default hotkey
    if (-not (Get-Command -Name Convert-HotKeySettingsToWin32 -ErrorAction SilentlyContinue)) {
        return $default
    }

    try {
        # Retrieve saved hotkey settings 
        $saved = Get-HotKeySettings

        # If no saved settings, return the default hotkey
        if (-not $saved) {
            return $default
        }

        # Convert saved settings to Win32 hotkey format
        $resolved = Convert-HotKeySettingsToWin32 -Settings $saved
        if (-not $resolved) {
            return $default
        }

        return $resolved
    }
    catch {
        return $default
    }
}

function Update-GlobalHotKeyRegistration {
    # If the form is not available or has been disposed, do not register hotkey
    if (-not $form -or $form.IsDisposed) {
        return $false
    }

    # If a global hotkey is already registered, unregister it first
    if ($script:globalHotKeyRegistered) {
        [void][Win32HotKey]::UnregisterHotKey($form.Handle, $script:globalHotKeyId)
        $script:globalHotKeyRegistered = $false
    }

    # Resolve the configured global hotkey
    $resolved = Resolve-ConfiguredGlobalHotKey
    $script:globalHotKeyModifierMask = [uint32]$resolved.ModifierMask
    $script:globalHotKeyVirtualKey = [uint32]$resolved.VirtualKey
    $script:globalHotKeyDisplayText = [string]$resolved.DisplayText

    # Register global hotkey
    $script:globalHotKeyRegistered = [Win32HotKey]::RegisterHotKey(
        $form.Handle,
        $script:globalHotKeyId,
        $script:globalHotKeyModifierMask,
        $script:globalHotKeyVirtualKey
    )

    return $script:globalHotKeyRegistered
}

# Toggle behavior: minimize if visible, otherwise restore near the cursor on the active screen.
$script:globalHotKeyFilter = New-Object GlobalHotKeyFilter
$script:globalHotKeyFilter.HotKeyId = $script:globalHotKeyId
$script:globalHotKeyFilter.Add_HotKeyPressed({
        # Determine target form to toggle. Essentially, everytime a new form appears, we're registering it as the active form so the hotkey always affects the most recent form.
        $targetForm = $script:activeForm

        # If the target form is not available or has been disposed, do nothing
        if (-not $targetForm -or $targetForm.IsDisposed) {
            return
        }

        # If target form is visible and not minimized, minimize it
        if ($targetForm.Visible -and $targetForm.WindowState -ne [System.Windows.Forms.FormWindowState]::Minimized) {
            $targetForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
            return
        }

        # When target form is not visible or minimized, restore it near the cursor on the active screen
        $cursorPosition = [System.Windows.Forms.Cursor]::Position
        $screen = [System.Windows.Forms.Screen]::FromPoint($cursorPosition)
        $workingArea = $screen.WorkingArea

        # Calculate position to restore the form near the cursor with an offset. 
        # Offset being the height of the title bar to ensure the form's title bar is aligned with the cursor.
        $restoreBounds = $targetForm.RestoreBounds
        $formWidth = if ($restoreBounds.Width -gt 0) { $restoreBounds.Width } else { $targetForm.Width }
        $formHeight = if ($restoreBounds.Height -gt 0) { $restoreBounds.Height } else { $targetForm.Height }
        $titleBarOffset = [Math]::Max(12, [System.Windows.Forms.SystemInformation]::CaptionHeight)
        
        $desiredX = $cursorPosition.X - [Math]::Floor($formWidth / 2)
        $desiredY = $cursorPosition.Y - $titleBarOffset

        $maxX = [Math]::Max($workingArea.Left, $workingArea.Right - $formWidth)
        $maxY = [Math]::Max($workingArea.Top, $workingArea.Bottom - $formHeight)
        $clampedX = [Math]::Max($workingArea.Left, [Math]::Min($desiredX, $maxX))
        $clampedY = [Math]::Max($workingArea.Top, [Math]::Min($desiredY, $maxY))

        # Apply the calculated position and restore the form
        $targetForm.StartPosition = 'Manual'
        $targetForm.Location = New-Object System.Drawing.Point($clampedX, $clampedY)
        $targetForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $targetForm.BringToFront()
        $targetForm.Activate()
    })

# Add the global hotkey filter to the application
[System.Windows.Forms.Application]::AddMessageFilter($script:globalHotKeyFilter)

$script:backNavFilter = New-Object BackNavFilter
$script:backNavFilter.Add_BackNavPressed({
        $target = $script:activeForm
        # If target form is available, not disposed, and not the main form, close it with Ctrl + Ctrl 
        if ($target -and -not $target.IsDisposed -and $target -ne $script:mainForm) {
            $target.Close()
        }
    })
[System.Windows.Forms.Application]::AddMessageFilter($script:backNavFilter)

$form.Add_Shown({
        # Register once the form has a valid window handle
        $script:globalHotKeyRegistered = Update-GlobalHotKeyRegistration

        # If global hotkey registration failed 
        if (-not $script:globalHotKeyRegistered) {
            [System.Windows.Forms.MessageBox]::Show(
                "Global hotkey $script:globalHotKeyDisplayText could not be registered.",
                "Hotkey Registration"
            ) | Out-Null
        }
    })

$form.Add_FormClosed({
        # Unregister global hotkey and remove message filters if they were registered
        if ($script:globalHotKeyRegistered) {
            [void][Win32HotKey]::UnregisterHotKey($form.Handle, $script:globalHotKeyId)
        }

        # If global hotkey filter was added, remove it
        if ($null -ne $script:globalHotKeyFilter) {
            [System.Windows.Forms.Application]::RemoveMessageFilter($script:globalHotKeyFilter)
        }

        # If back navigation filter was added, remove it
        if ($null -ne $script:backNavFilter) {
            [System.Windows.Forms.Application]::RemoveMessageFilter($script:backNavFilter)
        }
    })
