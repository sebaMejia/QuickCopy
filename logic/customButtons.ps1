# Sending to local AppData folder
$appDataFolder = Join-Path $env:APPDATA "QuickCopy"
if (-not (Test-Path $appDataFolder)) { New-Item -ItemType Directory -Path $appDataFolder | Out-Null }
$settingsFile = Join-Path $appDataFolder "customButtons.json"

# Initialize custom buttons JSON file and sections inside of it
$script:CustomButtonsFilePath = $settingsFile
$script:CustomButtonSections = @("Custom1", "Custom2", "Custom3", "Custom4", "Custom5", "Custom6", "Custom7", "Custom8", "Custom9", "Custom10")

# Create default custom buttons structure
function New-DefaultCustomButtons {
    return [PSCustomObject]@{
        Custom1  = @()
        Custom2  = @()
        Custom3  = @()
        Custom4  = @()
        Custom5  = @()
        Custom6  = @()
        Custom7  = @()
        Custom8  = @()
        Custom9  = @()
        Custom10 = @()
    }
}

function Initialize-CustomButtonSections {
    param(
        [Parameter(Mandatory)] $Buttons
    )

    # For each custom button section, ensure it exists and initialize it locally
    foreach ($section in $script:CustomButtonSections) {
        # Check if the section exists in the buttons object. If the section does not exist, add it as an empty array
        if (-not ($Buttons.PSObject.Properties.Name -contains $section)) {
            $Buttons | Add-Member -MemberType NoteProperty -Name $section -Value @()
        }
        # Check if the section is null. If it is, initialize it as an empty array
        elseif ($null -eq $Buttons.$section) {
            $Buttons.$section = @()
        }
        # Check if the section is not an array or collection. If it is not, convert it to an array. 
        elseif ($Buttons.$section -isnot [System.Collections.IEnumerable]) {
            $Buttons.$section = @($Buttons.$section)
        }
    }

    return $Buttons
}

function Import-CustomButtons {
    if (Test-Path $settingsFile) {
        $loadedButtons = Get-Content $settingsFile -Raw | ConvertFrom-Json
        # Return JSON object into initialized custom button sections
        return Initialize-CustomButtonSections -Buttons $loadedButtons
    }
    # If settings file does not exist, return default custom buttons 
    else {
        return New-DefaultCustomButtons
    }
}

function Save-CustomButtons($buttons) {
    # Save custom buttons to JSON file 
    $buttons | ConvertTo-Json -Depth 10 | Set-Content $settingsFile
}

function Get-NormalizedCustomButtons {
    param(
        [Parameter(Mandatory)] $Buttons
    )

    $Buttons = Initialize-CustomButtonSections -Buttons $Buttons

    # Read JSON file and normalize sections into a flat list of custom button objects
    $items = foreach ($customKey in $script:CustomButtonSections) {
        # Iterate through each button the the current custom section
        foreach ($btn in @($Buttons.$customKey)) {

            if ($null -eq $btn) { continue }

            $sectionHeader = $null

            # If the button has a 'Section Header' property, set the sectionHeader variable
            if ($btn.PSObject.Properties.Name -contains 'Section Header') {
                $sectionHeader = [string]$btn.'Section Header'
            }

            # Normalize button object
            [pscustomobject]@{
                CustomKey     = $customKey
                SectionHeader = $sectionHeader
                Text          = [string]$btn.Text
                Command       = [string]$btn.Command
                FilePath      = [string]$btn.FilePath
                Order         = $btn.Order
            }
        }
    }

    return $items
}
