$ErrorActionPreference = 'Stop'
$switcher = Join-Path (Split-Path $PSScriptRoot -Parent) 'switch-komorebi.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $switcher, [ref]$tokens, [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw ($parseErrors.Message -join "`n")
}

$starts = @($ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'komorebic' -and
        $node.CommandElements.Count -gt 1 -and
        $node.CommandElements[1].Extent.Text -eq 'start'
}, $true))
if ($starts.Count -ne 1) {
    throw 'Expected exactly one Komorebi start command in the profile switcher.'
}

# Run only the launch expression with a stub; never restart the user's desktop.
$script:launchArguments = @()
function komorebic {
    $script:launchArguments = @($args)
}
& ([scriptblock]::Create($starts[0].Extent.Text))
if ($launchArguments -notcontains '--clean-state') {
    throw 'Profile switches must ignore saved state that can replace the configured workspace count.'
}
if ($launchArguments -notcontains '--whkd') {
    throw 'Profile switches must continue starting the hotkey daemon.'
}
Write-Output 'PASS: profile startup ignores saved state and preserves hotkey startup.'
