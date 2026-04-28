# QuickCopy v1.0

QuickCopy is a Windows PowerShell + WinForms clipboard primarily for the IT field where
one might need to quickly grab a pre-saved prompt from File Explorer and paste it wherever.
This application is intended to reduce time spent in trying to type or locate presaved
texts, which can be tedious. The main objective as well is to have the end-user have complete
customizeability of the application itself to how they would like it to be.

Features:

- Window GUI for up to 10 custom sections.
- Up to 10 buttons per section for .txt presaved scripts or customize ones already set.
- Settings menu to add, edit, delete, rename, and reset buttons that hold text.
- Global hotkey for hiding/showing GUI for quick access at any time.
- Double-Ctrl back navigation for sub-windows for quick access to other prompts.

## Code Explanation

Startup Flow:

1. main.ps1 starts WinForms and resolves the application root.
2. main.ps1 imports core logic and settings scripts.
3. main.ps1 builds the main form and loads the section grid from clipboard/clipboardMenu.ps1.
4. Each section opens a dynamically-sized submenu from clipboard/clipboardGUI.ps1.
5. Sub-menu button clicks copy configured text or file contents to the clipboard.
6. Settings changes are written to AppData and used on the next launch.

At runtime, QuickCopy reads and writes user configuration under:

- %APPDATA%/QuickCopy/customButtons.json
- %APPDATA%/QuickCopy/hotkeySettings.json

## Project Structure and Responsibilities

### Root

- main.ps1
  - Application entry point.
  - Creates the main window.
  - Resolves app root for script mode and packaged EXE mode.
  - Loads script modules from logic, settings, and clipboard.

- build-exe.ps1
  - Build and packaging script for PS2EXE.
  - Creates a release bundle with QuickCopy.exe plus required folders.
  - Optionally installs ps2exe when missing.

### Clipboard

- clipboard/clipboardMenu.ps1
  - Builds the main menu GroupBox.
  - Dynamically labels section buttons from configuration.
  - Wires section buttons to submenu launch functions.

- clipboard/clipboardGUI.ps1
  - Creates section submenu forms.
  - Loads configured buttons for a selected section.
  - Handles no-button states, back button behavior, and form sizing.

### Logic

- logic/buttonFunctions.ps1
  - Shared UI helpers such as menu buttons and labels.
  - Validation and loader logic for button rendering.
  - Clipboard copy behavior for command text or file-backed content.

- logic/customButtons.ps1
  - Configuration storage for section/button data.
  - Creates defaults, imports JSON, normalizes sections, saves changes.
  - Stores user data in %APPDATA%/QuickCopy/customButtons.json.

- logic/hotkeyHideGUI.ps1
  - Registers global hotkey with Win32 interop.
  - Toggles active form minimize/restore near cursor for quick manuvering.
  - Adds back-navigation filter with double clicking Ctrl by default.

- logic/textBoxPolicies.ps1
  - Shared textbox policies and key handlers for redundancy.

### Settings

- settings/settings.ps1
  - Main settings menu UI.
  - Routes to add, edit, delete, and hotkey settings windows.
  - Reset to complete default is an option available.

- settings/addMenu.ps1
  - UI and validation for creating new custom buttons.
  - Supports typed text or uploaded text file as content source.

- settings/editMenu.ps1
  - Section rename workflow.
  - Button rename and button text edit workflow.

- settings/delMenu.ps1
  - Deletes selected buttons from selected sections.

- settings/hotkeyMenu.ps1
  - Captures and validates hotkey combinations.
  - Persists hotkey settings and converts to Win32-compatible values.

### Publish

- publish/QuickCopy/\*
  - Build output snapshot for distribution.
  - Mirrors runtime files needed by the EXE.
  - Not required in source control for normal development.

## Data Model

customButtons.json contains:

- Custom1 through Custom10 arrays
- Each button object includes:
  - Section Header
  - Text
  - Command
  - Optional FilePath
- Optional SectionHeaders object for section display names

## Runtime behavior details

- Main window shows 10 section buttons in a two-column layout.
- Section display names are resolved from:
  1. First non-empty Section Header on buttons in that slot
  2. SectionHeaders fallback map
  3. Slot name (Custom1..Custom10)
- Section submenu shows up to 10 buttons.
- Button click behavior:
  - If FilePath is set, read that file and copy content to clipboard.
  - Else if Command has text, copy Command text to clipboard.
  - Else show configuration warning.

## Build and Package

Recommended ot install the latest version of ps2exe beforehand. From the repository root, run:

powershell -ExecutionPolicy Bypass -File .\build-exe.ps1 -InstallDependencies

Default output:

- publish/QuickCopy/QuickCopy.exe
- publish/QuickCopy/logic
- publish/QuickCopy/settings
- publish/QuickCopy/clipboard
