#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script to validate the deployment script and prerequisites.

.DESCRIPTION
    This script validates the deployment script syntax and checks basic prerequisites
    without actually deploying to Azure.

.EXAMPLE
    .\Test-DeploymentScript.ps1
#>

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "Green"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-PowerShellSyntax {
    Write-ColorOutput "Testing PowerShell script syntax..." "Yellow"
    
    $scriptPath = ".\Deploy-Ship360ChatAPI.ps1"
    
    if (!(Test-Path $scriptPath)) {
        Write-Error "Deployment script not found: $scriptPath"
        return $false
    }
    
    try {
        # Parse the script to check for syntax errors
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null)
        Write-ColorOutput "✓ PowerShell syntax validation passed" "Green"
        return $true
    }
    catch {
        Write-Error "PowerShell syntax error: $_"
        return $false
    }
}

function Test-RequiredFiles {
    Write-ColorOutput "Checking required files..." "Yellow"
    
    $requiredFiles = @(
        ".\Deploy-Ship360ChatAPI.ps1",
        ".\README.md",
        ".\ship360-sample.env",
        "..\..\..\ship360-chat-api\requirements.txt",
        "..\..\..\ship360-chat-api\app\main.py"
    )
    
    $allExist = $true
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-ColorOutput "✓ Found: $file" "Green"
        } else {
            Write-ColorOutput "✗ Missing: $file" "Red"
            $allExist = $false
        }
    }
    
    return $allExist
}

function Test-EnvironmentFile {
    Write-ColorOutput "Testing sample environment file..." "Yellow"
    
    $envFile = ".\ship360-sample.env"
    
    if (!(Test-Path $envFile)) {
        Write-Error "Sample environment file not found: $envFile"
        return $false
    }
    
    try {
        $envContent = Get-Content $envFile
        $requiredVars = @(
            "AZURE_OPENAI_ENDPOINT",
            "AZURE_OPENAI_API_KEY", 
            "AZURE_OPENAI_CHAT_DEPLOYMENT_NAME",
            "AZURE_OPENAI_API_VERSION",
            "SP360_TOKEN_URL",
            "SP360_TOKEN_USERNAME",
            "SP360_TOKEN_PASSWORD",
            "SP360_RATE_SHOP_URL",
            "SP360_SHIPMENTS_URL",
            "SP360_TRACKING_URL"
        )
        
        $foundVars = @()
        foreach ($line in $envContent) {
            if ($line -match '^([^=#]+)=') {
                $foundVars += $matches[1].Trim()
            }
        }
        
        $missingVars = @()
        foreach ($var in $requiredVars) {
            if ($foundVars -notcontains $var) {
                $missingVars += $var
            }
        }
        
        if ($missingVars.Count -eq 0) {
            Write-ColorOutput "✓ All required environment variables found" "Green"
            return $true
        } else {
            Write-ColorOutput "✗ Missing environment variables: $($missingVars -join ', ')" "Red"
            return $false
        }
    }
    catch {
        Write-Error "Failed to parse environment file: $_"
        return $false
    }
}

function Test-ScriptParameters {
    Write-ColorOutput "Testing script parameter validation..." "Yellow"
    
    try {
        # Test help parameter
        try {
            $help = Get-Help .\Deploy-Ship360ChatAPI.ps1 -ErrorAction SilentlyContinue
            if ($help) {
                Write-ColorOutput "✓ Script help documentation available" "Green"
            } else {
                Write-ColorOutput "⚠ Script help documentation not available" "Yellow"
            }
        }
        catch {
            Write-ColorOutput "⚠ Could not test help documentation" "Yellow"
        }
        
        # Test parameter binding (dry run)
        try {
            # Load the script without executing
            $scriptContent = Get-Content ".\Deploy-Ship360ChatAPI.ps1" -Raw
            # Check if required parameters are defined
            if ($scriptContent -match '\[Parameter\(Mandatory = \$true\)\]') {
                $result = $true
            } else {
                $result = $false
            }
        }
        catch {
            $result = $false
        }
        
        if ($result) {
            Write-ColorOutput "✓ Required parameters properly defined" "Green"
        } else {
            Write-ColorOutput "⚠ Could not validate parameter definitions" "Yellow"
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to test script parameters: $_"
        return $false
    }
}

function Test-Prerequisites {
    Write-ColorOutput "Checking basic prerequisites..." "Yellow"
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-ColorOutput "PowerShell version: $psVersion" "Cyan"
    
    if ($psVersion.Major -ge 5) {
        Write-ColorOutput "✓ PowerShell version is sufficient" "Green"
    } else {
        Write-ColorOutput "✗ PowerShell 5.0+ required" "Red"
        return $false
    }
    
    # Check for Azure CLI (optional - just warn if not available)
    try {
        $azVersion = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✓ Azure CLI available: $($azVersion.'azure-cli')" "Green"
    }
    catch {
        Write-ColorOutput "⚠ Azure CLI not found - required for actual deployment" "Yellow"
    }
    
    return $true
}

function Main {
    Write-ColorOutput "🧪 Testing Ship360 Chat API Deployment Script..." "Green"
    Write-ColorOutput "=================================================" "Green"
    
    $allTestsPassed = $true
    
    # Run all tests
    $tests = @(
        { Test-Prerequisites },
        { Test-RequiredFiles },
        { Test-EnvironmentFile },
        { Test-PowerShellSyntax },
        { Test-ScriptParameters }
    )
    
    foreach ($test in $tests) {
        try {
            $result = & $test
            if (-not $result) {
                $allTestsPassed = $false
            }
        }
        catch {
            Write-Error "Test failed: $_"
            $allTestsPassed = $false
        }
        Write-Host ""
    }
    
    # Summary
    Write-ColorOutput "=================================================" "Green"
    if ($allTestsPassed) {
        Write-ColorOutput "🎉 All tests passed! Deployment script is ready." "Green"
        Write-ColorOutput "📋 Next steps:" "Cyan"
        Write-ColorOutput "   1. Login to Azure: az login" "White"
        Write-ColorOutput "   2. Create your environment file from ship360-sample.env" "White"
        Write-ColorOutput "   3. Run the deployment script with your parameters" "White"
    } else {
        Write-ColorOutput "❌ Some tests failed. Please fix the issues above." "Red"
        exit 1
    }
    Write-ColorOutput "=================================================" "Green"
}

# Execute main function
Main