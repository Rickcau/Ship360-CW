# Test-DeploymentScript.ps1
# This script tests the Deploy-Ship360ChatAPI.ps1 script without actually deploying to Azure

param(
    [Parameter(Mandatory = $false)]
    [string]$EnvFilePath = "./ship360-sample.env",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-ship360-test",
    
    [Parameter(Mandatory = $false)]
    [string]$AppServiceName = "app-ship360-chat-test"
)

# Import module for Test-ScriptFileInfo if available
if (Get-Command Test-ScriptFileInfo -ErrorAction SilentlyContinue) {
    Write-Host "Testing script metadata..." -ForegroundColor Yellow
    try {
        $scriptInfo = Test-ScriptFileInfo -Path ./Deploy-Ship360ChatAPI.ps1 -ErrorAction Stop
        Write-Host "✓ Script metadata is valid" -ForegroundColor Green
        Write-Host "  Version: $($scriptInfo.Version)" -ForegroundColor Gray
        Write-Host "  Author: $($scriptInfo.Author)" -ForegroundColor Gray
    }
    catch {
        Write-Host "⚠️ Script metadata test skipped or invalid: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Test 1: Verify script exists
Write-Host "Test 1: Verifying script exists..." -ForegroundColor Yellow
if (Test-Path ./Deploy-Ship360ChatAPI.ps1) {
    Write-Host "✓ Script file exists" -ForegroundColor Green
} else {
    Write-Host "❌ Script file not found" -ForegroundColor Red
    exit 1
}

# Test 2: Check PowerShell syntax
Write-Host "Test 2: Checking PowerShell syntax..." -ForegroundColor Yellow
try {
    $null = [System.Management.Automation.ScriptBlock]::Create((Get-Content ./Deploy-Ship360ChatAPI.ps1 -Raw))
    Write-Host "✓ PowerShell syntax is valid" -ForegroundColor Green
} catch {
    Write-Host "❌ PowerShell syntax error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Check if environment file exists
Write-Host "Test 3: Checking environment file..." -ForegroundColor Yellow
if (Test-Path $EnvFilePath) {
    Write-Host "✓ Environment file exists: $EnvFilePath" -ForegroundColor Green
    
    # Test environment file format
    $validEnvFile = $false
    try {
        $envContent = Get-Content $EnvFilePath
        $variableCount = 0
        
        foreach ($line in $envContent) {
            if ($line -match '^([^#][^=]+)=(.*)$') {
                $variableCount++
            }
        }
        
        if ($variableCount -gt 0) {
            Write-Host "✓ Environment file contains $variableCount variables" -ForegroundColor Green
            $validEnvFile = $true
        } else {
            Write-Host "⚠️ Environment file has no variables" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ Could not parse environment file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Environment file not found: $EnvFilePath" -ForegroundColor Yellow
    Write-Host "  Sample environment file will be used for testing" -ForegroundColor Yellow
    
    # Create a temporary environment file for testing
    $tempEnvFile = "./temp-test.env"
    @"
# Temporary test environment file
PROJECT_NAME="Ship360 Chat API Test"
DEBUG="false"
ENVIRONMENT="test"
LOG_LEVEL="debug"
"@ | Out-File -FilePath $tempEnvFile -Encoding utf8
    
    Write-Host "✓ Created temporary environment file: $tempEnvFile" -ForegroundColor Green
    $EnvFilePath = $tempEnvFile
    $validEnvFile = $true
}

# Test 4: Check Azure CLI
Write-Host "Test 4: Checking Azure CLI installation..." -ForegroundColor Yellow
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "✓ Azure CLI is installed (Version: $($azVersion.'azure-cli'))" -ForegroundColor Green
    
    # Check if logged in
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green
        Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
    } catch {
        Write-Host "⚠️ Not logged into Azure (script will prompt for login)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Azure CLI not found or not in PATH" -ForegroundColor Yellow
    Write-Host "  The deployment script will fail without Azure CLI" -ForegroundColor Yellow
}

# Test 5: Check source code path
Write-Host "Test 5: Checking source code path..." -ForegroundColor Yellow
$sourcePath = "../../../ship360-chat-api"
if (Test-Path $sourcePath) {
    Write-Host "✓ Source code path exists: $sourcePath" -ForegroundColor Green
    
    # Check for key files
    $requiredFiles = @(
        "requirements.txt",
        "app/main.py"
    )
    
    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $sourcePath $file
        if (!(Test-Path $filePath)) {
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -eq 0) {
        Write-Host "✓ All required files found in source directory" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Missing required files: $($missingFiles -join ', ')" -ForegroundColor Yellow
        Write-Host "  The deployment script may fail without these files" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Source code path not found: $sourcePath" -ForegroundColor Yellow
    Write-Host "  The deployment script may fail without valid source code" -ForegroundColor Yellow
}

# Test 6: Mock deployment test (doesn't actually deploy)
Write-Host "Test 6: Running mock deployment test..." -ForegroundColor Yellow
Write-Host "  This test will execute the first part of the script (prerequisites check)" -ForegroundColor Gray
Write-Host "  but will not actually create resources or deploy code" -ForegroundColor Gray

# Create a mock function to replace actual execution
$mockScript = @"
# Mock version of Deploy-Ship360ChatAPI.ps1 for testing
param(
    [Parameter(Mandatory = `$true)]
    [string]`$ResourceGroupName,
    
    [Parameter(Mandatory = `$true)]
    [string]`$AppServiceName,
    
    [Parameter(Mandatory = `$false)]
    [string]`$Location = "eastus",
    
    [Parameter(Mandatory = `$false)]
    [string]`$EnvironmentFile = "$EnvFilePath"
)

# Source the original script but extract only the functions
. {
    `$scriptContent = Get-Content -Path ./Deploy-Ship360ChatAPI.ps1 -Raw
    `$scriptBlock = [ScriptBlock]::Create(`$scriptContent)
    
    # Extract functions only
    foreach (`$item in `$scriptBlock.Ast.FindAll({ `$args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, `$true)) {
        `$functionContent = `$item.Extent.Text
        Invoke-Expression `$functionContent
    }
}

# Write colored output
function Write-ColorOutput {
    param(
        [string]`$Message,
        [string]`$Color = "Green"
    )
    Write-Host `$Message -ForegroundColor `$Color
}

# Mock execution - only run prerequisite checks
Write-ColorOutput "🚀 Starting MOCK deployment (test only - no actual deployment)" "Cyan"
Write-ColorOutput "=================================================" "Cyan"
Write-ColorOutput "Resource Group: `$ResourceGroupName" "White"
Write-ColorOutput "App Service: `$AppServiceName" "White"
Write-ColorOutput "Location: `$Location" "White"
Write-ColorOutput "Environment File: `$EnvironmentFile" "White"
Write-ColorOutput "=================================================" "Cyan"

# Run only the prerequisites check
Test-Prerequisites

Write-ColorOutput "✓ Mock test completed successfully!" "Green"
Write-ColorOutput "This was a test only - no resources were created or deployed" "Yellow"
"@

# Save mock script to temporary file
$mockScriptPath = "./temp-mock-deploy.ps1"
$mockScript | Out-File -FilePath $mockScriptPath -Encoding utf8

# Run the mock script with minimal parameters
try {
    & pwsh -File $mockScriptPath -ResourceGroupName $ResourceGroupName -AppServiceName $AppServiceName -ErrorAction Stop
    Write-Host "✓ Mock deployment test completed successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Mock deployment test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  This may indicate issues with the script" -ForegroundColor Yellow
}

# Clean up temporary files
if (Test-Path $mockScriptPath) { Remove-Item $mockScriptPath -Force }
if (Test-Path "./temp-test.env") { Remove-Item "./temp-test.env" -Force }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Deployment Script Test Complete" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To deploy to Azure, run:" -ForegroundColor Yellow
Write-Host "  .\Deploy-Ship360ChatAPI.ps1 -ResourceGroupName '$ResourceGroupName' -AppServiceName '$AppServiceName' -EnvironmentFile '$EnvFilePath'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Make sure you have:" -ForegroundColor Yellow
Write-Host "  1. Azure CLI installed and logged in (az login)" -ForegroundColor White
Write-Host "  2. Valid environment file with required settings" -ForegroundColor White
Write-Host "  3. Appropriate Azure permissions to create resources" -ForegroundColor White
Write-Host ""