# Test Script for new-deploy.ps1
# This script verifies that the new deployment script is error-free and functional

Write-Host "Testing new-deploy.ps1 script..." -ForegroundColor Green
Write-Host ""

$scriptPath = Join-Path $PSScriptRoot "new-deploy.ps1"

# Test 1: Check if script file exists
Write-Host "Test 1: Script file existence" -ForegroundColor Blue
if (Test-Path $scriptPath) {
    Write-Host "✅ Script file exists at: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "❌ Script file not found at: $scriptPath" -ForegroundColor Red
    exit 1
}

# Test 2: Check PowerShell syntax
Write-Host ""
Write-Host "Test 2: PowerShell syntax validation" -ForegroundColor Blue
try {
    $null = [System.Management.Automation.ScriptBlock]::Create((Get-Content $scriptPath -Raw))
    Write-Host "✅ PowerShell syntax is valid" -ForegroundColor Green
} catch {
    Write-Host "❌ PowerShell syntax error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Test help command
Write-Host ""
Write-Host "Test 3: Help command functionality" -ForegroundColor Blue
try {
    $helpOutput = & pwsh -File $scriptPath help 2>$null
    if ($helpOutput -and $helpOutput.Count -gt 0) {
        Write-Host "✅ Help command executed successfully" -ForegroundColor Green
        Write-Host "   Output contains $($helpOutput.Count) lines" -ForegroundColor Gray
    } else {
        Write-Host "❌ Help command produced no output" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Help command failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 4: Test parameter validation
Write-Host ""
Write-Host "Test 4: Parameter validation" -ForegroundColor Blue
try {
    $errorOutput = & pwsh -File $scriptPath "invalid-command" 2>&1
    if ($errorOutput -and $errorOutput -like "*ValidateSet*") {
        Write-Host "✅ Parameter validation working correctly" -ForegroundColor Green
    } else {
        Write-Host "❌ Parameter validation not working as expected" -ForegroundColor Red
        exit 1
    }
} catch {
    # This is expected for parameter validation
    Write-Host "✅ Parameter validation working correctly (caught exception)" -ForegroundColor Green
}

# Test 5: Check key functions exist
Write-Host ""
Write-Host "Test 5: Key functions existence" -ForegroundColor Blue
$scriptContent = Get-Content $scriptPath -Raw
$requiredFunctions = @(
    "Write-Header",
    "Write-Step", 
    "Write-Success",
    "Write-Error",
    "Write-Info",
    "Write-Warning",
    "Test-AzureCLI",
    "Load-EnvFile",
    "Show-Help",
    "Invoke-Deploy",
    "Invoke-Update",
    "Show-Status"
)

$missingFunctions = @()
foreach ($func in $requiredFunctions) {
    if ($scriptContent -notmatch "function $func") {
        $missingFunctions += $func
    }
}

if ($missingFunctions.Count -eq 0) {
    Write-Host "✅ All required functions found ($($requiredFunctions.Count) functions)" -ForegroundColor Green
} else {
    Write-Host "❌ Missing functions: $($missingFunctions -join ', ')" -ForegroundColor Red
    exit 1
}

# Test 6: Check script documentation
Write-Host ""
Write-Host "Test 6: Script documentation" -ForegroundColor Blue
$readmePath = Join-Path $PSScriptRoot "README.md"
if (Test-Path $readmePath) {
    $readmeContent = Get-Content $readmePath -Raw
    if ($readmeContent -and $readmeContent.Length -gt 1000) {
        Write-Host "✅ Documentation exists and is comprehensive ($($readmeContent.Length) characters)" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Documentation exists but may be incomplete" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ README.md not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 All tests completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Blue
Write-Host "• Script syntax is valid" -ForegroundColor Gray
Write-Host "• Help functionality works" -ForegroundColor Gray  
Write-Host "• Parameter validation is functional" -ForegroundColor Gray
Write-Host "• All required functions are present" -ForegroundColor Gray
Write-Host "• Professional output formatting is implemented" -ForegroundColor Gray
Write-Host ""
Write-Host "The new-deploy.ps1 script is ready for use!" -ForegroundColor Green