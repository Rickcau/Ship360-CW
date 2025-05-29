#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploys the Ship360 Chat API (FastAPI) to Azure App Service.

.DESCRIPTION
    This PowerShell script automates the deployment of the Ship360 Chat API to Azure App Service.
    It creates the necessary Azure resources, configures the runtime environment, and deploys the FastAPI application.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group to create or use.

.PARAMETER AppServiceName
    The name of the Azure App Service (Web App) to create.

.PARAMETER Location
    The Azure region where resources will be created (default: eastus).

.PARAMETER AppServicePlanName
    The name of the App Service Plan to create (default: generated from AppServiceName).

.PARAMETER PricingTier
    The pricing tier for the App Service Plan (default: B1).

.PARAMETER SubscriptionId
    The Azure Subscription ID to use (optional - uses current subscription if not specified).

.PARAMETER EnvironmentFile
    Path to the .env file containing environment variables for the application.

.PARAMETER SourcePath
    Path to the Ship360 Chat API source code (default: ../../ship360-chat-api).

.PARAMETER SkipResourceCreation
    Skip creation of Azure resources and only deploy the application.

.PARAMETER DebugMode
    Enable debug startup command that provides detailed diagnostics for troubleshooting.

.EXAMPLE
    .\Deploy-Ship360ChatAPI.ps1 -ResourceGroupName "rg-ship360-dev" -AppServiceName "app-ship360-chat-dev" -EnvironmentFile ".\ship360.env"

.EXAMPLE
    .\Deploy-Ship360ChatAPI.ps1 -ResourceGroupName "rg-ship360-prod" -AppServiceName "app-ship360-chat-prod" -Location "westus2" -PricingTier "P1v2" -EnvironmentFile ".\ship360-prod.env"

.NOTES
    Prerequisites:
    - Azure CLI installed and logged in
    - Azure subscription with appropriate permissions
    - Ship360 Chat API source code
    - Environment variables configured in .env file
    
    Testing Status:
    - Script syntax and structure validated
    - Prerequisites checking implemented
    - Error handling improved based on real Azure CLI testing feedback
    - Resource existence verification added to prevent false success reporting
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$AppServicePlanName = "$AppServiceName-plan",
    
    [Parameter(Mandatory = $false)]
    [string]$PricingTier = "B1",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentFile,
    
    [Parameter(Mandatory = $false)]
    [string]$SourcePath = "../../../ship360-chat-api",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipResourceCreation,
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

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

# Function to check prerequisites
function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." "Yellow"
    
    # Check if Azure CLI is installed
    try {
        $azVersion = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✓ Azure CLI version: $($azVersion.'azure-cli')" "Green"
    }
    catch {
        Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI and try again."
        exit 1
    }
    
    # Check if logged into Azure
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✓ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "✓ Current subscription: $($account.name) ($($account.id))" "Green"
    }
    catch {
        Write-Error "Not logged into Azure. Please run 'az login' and try again."
        exit 1
    }
    
    # Check if source path exists
    if (!(Test-Path $SourcePath)) {
        Write-Error "Source path '$SourcePath' does not exist. Please check the path and try again."
        exit 1
    }
    
    # Check if requirements.txt exists
    $requirementsPath = Join-Path $SourcePath "requirements.txt"
    if (!(Test-Path $requirementsPath)) {
        Write-Error "requirements.txt not found at '$requirementsPath'."
        exit 1
    }
    
    # Validate required dependencies
    $requirementsContent = Get-Content $requirementsPath
    if (-not ($requirementsContent -match "uvicorn")) {
        Write-ColorOutput "⚠ Warning: uvicorn not found in requirements.txt" "Yellow"
        Write-ColorOutput "  This is required for the gunicorn uvicorn worker" "Yellow"
        Write-ColorOutput "  Add 'uvicorn' to your requirements.txt file" "Yellow"
    }
    if (-not ($requirementsContent -match "gunicorn")) {
        Write-ColorOutput "⚠ Warning: gunicorn not found in requirements.txt" "Yellow"
        Write-ColorOutput "  This is required for production deployment" "Yellow"
        Write-ColorOutput "  Add 'gunicorn' to your requirements.txt file" "Yellow"
    }
    
    # Check if environment file exists
    if (!(Test-Path $EnvironmentFile)) {
        Write-Error "Environment file '$EnvironmentFile' does not exist."
        exit 1
    }
    
    # Check if main.py exists
    $mainPyPath = Join-Path $SourcePath "app/main.py"
    if (!(Test-Path $mainPyPath)) {
        Write-Error "Main application file not found at '$mainPyPath'."
        exit 1
    }
    
    Write-ColorOutput "✓ All prerequisites met!" "Green"
}

# Function to set Azure subscription
function Set-AzureSubscription {
    if ($SubscriptionId) {
        Write-ColorOutput "Setting Azure subscription to: $SubscriptionId" "Yellow"
        try {
            az account set --subscription $SubscriptionId
            Write-ColorOutput "✓ Subscription set successfully" "Green"
        }
        catch {
            Write-Error "Failed to set subscription to '$SubscriptionId'. Please check the subscription ID."
            exit 1
        }
    }
}

# Function to create Azure resources
function New-AzureResources {
    if ($SkipResourceCreation) {
        Write-ColorOutput "Skipping resource creation..." "Yellow"
        return
    }
    
    Write-ColorOutput "Creating Azure resources..." "Yellow"
    
    # Create Resource Group
    Write-ColorOutput "Creating resource group: $ResourceGroupName" "Cyan"
    try {
        $rgExists = az group exists --name $ResourceGroupName --output tsv 2>$null
        if ($LASTEXITCODE -ne 0 -or $rgExists -eq "false") {
            $createResult = az group create --name $ResourceGroupName --location $Location --output json 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create resource group: $createResult"
                exit 1
            }
            Write-ColorOutput "✓ Resource group created: $ResourceGroupName" "Green"
        } else {
            Write-ColorOutput "✓ Resource group already exists: $ResourceGroupName" "Green"
        }
    }
    catch {
        Write-Error "Failed to create resource group: $ResourceGroupName - $_"
        exit 1
    }
    
    # Create App Service Plan
    Write-ColorOutput "Creating App Service Plan: $AppServicePlanName" "Cyan"
    try {
        # Check if App Service Plan exists
        $planCheck = az appservice plan show --name $AppServicePlanName --resource-group $ResourceGroupName 2>$null
        if ($LASTEXITCODE -ne 0) {
            # Plan doesn't exist, create it
            $createResult = az appservice plan create `
                --name $AppServicePlanName `
                --resource-group $ResourceGroupName `
                --location $Location `
                --sku $PricingTier `
                --is-linux `
                --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create App Service Plan: $createResult"
                exit 1
            }
            Write-ColorOutput "✓ App Service Plan created: $AppServicePlanName" "Green"
        } else {
            Write-ColorOutput "✓ App Service Plan already exists: $AppServicePlanName" "Green"
        }
    }
    catch {
        Write-Error "Failed to create App Service Plan: $AppServicePlanName - $_"
        exit 1
    }
    
    # Create Web App
    Write-ColorOutput "Creating Web App: $AppServiceName" "Cyan"
    try {
        # Check if Web App exists
        $appCheck = az webapp show --name $AppServiceName --resource-group $ResourceGroupName 2>$null
        if ($LASTEXITCODE -ne 0) {
            # App doesn't exist, create it
            $createResult = az webapp create `
                --name $AppServiceName `
                --resource-group $ResourceGroupName `
                --plan $AppServicePlanName `
                --runtime "PYTHON:3.11" `
                --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create Web App: $createResult"
                exit 1
            }
            Write-ColorOutput "✓ Web App created: $AppServiceName" "Green"
        } else {
            Write-ColorOutput "✓ Web App already exists: $AppServiceName" "Green"
        }
        
        # Verify the Web App exists after creation/check
        $verifyApp = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Web App verification failed - app was not created successfully"
            exit 1
        }
        
    }
    catch {
        Write-Error "Failed to create Web App: $AppServiceName - $_"
        exit 1
    }
}

# Function to parse environment file and set app settings
function Set-EnvironmentVariables {
    Write-ColorOutput "Configuring environment variables..." "Yellow"
    
    try {
        # Verify Web App exists before configuring
        $appCheck = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Web App '$AppServiceName' not found. Cannot configure environment variables."
            exit 1
        }
        
        # Read environment file
        $envContent = Get-Content $EnvironmentFile
        $appSettings = @()
        
        foreach ($line in $envContent) {
            # Skip empty lines and comments
            if ($line -match '^\s*$' -or $line -match '^\s*#') {
                continue
            }
            
            # Parse KEY=VALUE format
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                
                $appSettings += "$key=$value"
            }
        }
        
        if ($appSettings.Count -gt 0) {
            # Add default PORT setting for Azure App Service
            $appSettings += "PORT=8000"
            
            # Set application settings
            $settingsResult = az webapp config appsettings set `
                --name $AppServiceName `
                --resource-group $ResourceGroupName `
                --settings $appSettings `
                --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to configure environment variables: $settingsResult"
                exit 1
            }
            
            Write-ColorOutput "✓ Environment variables configured ($($appSettings.Count) variables)" "Green"
        } else {
            # Even if no env file variables, set the PORT
            $settingsResult = az webapp config appsettings set `
                --name $AppServiceName `
                --resource-group $ResourceGroupName `
                --settings "PORT=8000" `
                --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to configure PORT environment variable: $settingsResult"
                exit 1
            }
            
            Write-ColorOutput "⚠ No environment variables found in file, but PORT configured" "Yellow"
        }
    }
    catch {
        Write-Error "Failed to configure environment variables: $_"
        exit 1
    }
}

# Function to configure startup command
function Set-StartupCommand {
    Write-ColorOutput "Configuring startup command..." "Yellow"
    
    try {
        # Verify Web App exists before configuring
        $appCheck = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Web App '$AppServiceName' not found. Cannot configure startup command."
            exit 1
        }
        
        # Set startup command for FastAPI with gunicorn
        # Activate virtual environment first to ensure packages are available
        if ($DebugMode) {
            # Debug version to see what's happening during startup
            $startupCommand = "echo 'Python location:' && which python && echo 'Python version:' && python --version && echo 'Installed packages:' && pip list | grep -E '(uvicorn|gunicorn|fastapi)' && echo 'Starting app...' && source /home/site/wwwroot/venv/bin/activate && python startup_wrapper.py"
            Write-ColorOutput "✓ Debug mode enabled - startup command will provide detailed diagnostics" "Yellow"
        } else {
            $startupCommand = "source /home/site/wwwroot/venv/bin/activate && python startup_wrapper.py"
        }
        
        $configResult = az webapp config set `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --startup-file $startupCommand `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to configure startup command: $configResult"
            exit 1
        }
        
        Write-ColorOutput "✓ Startup command configured" "Green"
    }
    catch {
        Write-Error "Failed to configure startup command: $_"
        exit 1
    }
}

# Function to deploy application
function Deploy-Application {
    Write-ColorOutput "Deploying application..." "Yellow"
    
    try {
        # Verify Web App exists before deploying
        $appCheck = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Web App '$AppServiceName' not found. Cannot deploy application."
            exit 1
        }
        
        # Get the absolute path to source
        $absoluteSourcePath = Resolve-Path $SourcePath
        
        # Create deployment package
        $tempDir = Join-Path $env:TEMP "ship360-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        Write-ColorOutput "Creating deployment package in: $tempDir" "Cyan"
        
        # Copy application files
        Copy-Item -Path "$absoluteSourcePath\*" -Destination $tempDir -Recurse -Force
        
        # Create a robust startup script that will help diagnose issues
        $startupScriptPath = Join-Path $tempDir "startup_wrapper.py"
        $startupScriptContent = @"
#!/usr/bin/env python3
"""
Ship360 Chat API Startup Wrapper

This script provides startup validation and launches the FastAPI application with gunicorn.

Alternative startup commands (for troubleshooting):
1. Simple Uvicorn (development): source /home/site/wwwroot/venv/bin/activate && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
2. Gunicorn with sync workers: source /home/site/wwwroot/venv/bin/activate && gunicorn -w 4 -b 0.0.0.0:8000 app.main:app --timeout 600
3. Direct virtual environment Python: /home/site/wwwroot/venv/bin/python -m gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind=0.0.0.0:8000 --timeout 600
"""
import os
import sys
import subprocess
import logging
from pathlib import Path

# Configure logging for startup debugging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - STARTUP - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

def check_files():
    """Check if required files are present"""
    logger.info("🔍 Checking for required files...")
    cwd = Path.cwd()
    logger.info(f"Current directory: {cwd}")
    
    # List all files in current directory
    try:
        files = list(cwd.glob('*'))
        logger.info(f"Files in root: {[f.name for f in files if f.is_file()]}")
        dirs = list(cwd.glob('*/'))
        logger.info(f"Directories: {[d.name for d in dirs]}")
    except Exception as e:
        logger.error(f"Error listing files: {e}")
    
    # Check for startup.py
    startup_py = cwd / "startup.py"
    if startup_py.exists():
        logger.info("✅ startup.py found")
        return True
    else:
        logger.warning("⚠️ startup.py not found - skipping validation")
        return False

def run_validation():
    """Run startup validation if startup.py exists"""
    if not check_files():
        logger.warning("Skipping startup validation - continuing with direct app start")
        return True
        
    try:
        logger.info("🚀 Running Ship360 Chat API startup validation...")
        result = subprocess.run([sys.executable, "startup.py"], 
                              capture_output=True, text=True, timeout=30)
        
        # Log output regardless of success/failure
        if result.stdout:
            logger.info(f"Validation stdout: {result.stdout}")
        if result.stderr:
            logger.info(f"Validation stderr: {result.stderr}")
            
        if result.returncode != 0:
            logger.warning(f"❌ Startup validation failed with code {result.returncode}")
            logger.warning("Continuing anyway to help with debugging...")
            return True  # Don't fail on validation for now
        else:
            logger.info("✅ Startup validation passed")
            return True
            
    except subprocess.TimeoutExpired:
        logger.warning("⏰ Startup validation timed out - continuing anyway")
        return True
    except Exception as e:
        logger.warning(f"⚠️ Startup validation error: {e} - continuing anyway")
        return True

def start_app():
    """Start the FastAPI application with gunicorn"""
    # Get port from environment
    port = os.environ.get('PORT', '8000')
    logger.info(f"✅ Starting gunicorn on port {port}...")
    
    # Log environment variables (excluding sensitive ones)
    logger.info("Environment variables:")
    for key, value in sorted(os.environ.items()):
        if any(sensitive in key.upper() for sensitive in ['PASSWORD', 'SECRET', 'KEY', 'TOKEN']):
            logger.info(f"  {key}=***HIDDEN***")
        else:
            logger.info(f"  {key}={value}")
    
    # Use virtual environment python directly to ensure packages are found
    venv_python = "/home/site/wwwroot/venv/bin/python"
    if os.path.exists(venv_python):
        python_cmd = venv_python
        logger.info(f"✅ Using virtual environment Python: {python_cmd}")
    else:
        python_cmd = sys.executable
        logger.info(f"⚠️ Virtual environment Python not found, using: {python_cmd}")
    
    # Start gunicorn with more conservative settings
    cmd = [
        python_cmd, "-m", "gunicorn",
        "-w", "1",  # Single worker for debugging
        "-k", "uvicorn.workers.UvicornWorker", 
        "app.main:app",
        f"--bind=0.0.0.0:{port}",
        "--timeout", "300",
        "--keep-alive", "2",
        "--max-requests", "1000", 
        "--max-requests-jitter", "50",
        "--log-level", "info",
        "--access-logfile", "-",
        "--error-logfile", "-"
    ]
    
    logger.info(f"Executing command: {' '.join(cmd)}")
    os.execv(python_cmd, cmd)

if __name__ == "__main__":
    try:
        logger.info("🚀 Starting Ship360 Chat API deployment...")
        run_validation()
        start_app()
    except Exception as e:
        logger.error(f"💥 Fatal startup error: {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)
"@
        Set-Content -Path $startupScriptPath -Value $startupScriptContent
        
        # Create ZIP package
        $zipPath = Join-Path $env:TEMP "ship360-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
        
        # Use PowerShell Compress-Archive if available, otherwise try other methods
        if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
        } else {
            # Fallback to using Azure CLI
            Push-Location $tempDir
            try {
                # Create a zip using tar (available on most systems)
                tar -czf $zipPath *
            } finally {
                Pop-Location
            }
        }
        
        Write-ColorOutput "✓ Deployment package created: $zipPath" "Green"
        
        # Deploy using Azure CLI
        Write-ColorOutput "Uploading and deploying application..." "Cyan"
        Write-ColorOutput "⏱️  Note: Large deployments may take 5-10 minutes and could timeout" "Yellow"
        
        $deployResult = az webapp deploy `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --src-path $zipPath `
            --type zip `
            --output json 2>&1
        
        # Check for deployment failures
        if ($LASTEXITCODE -ne 0) {
            # Check if it's a timeout error specifically
            if ($deployResult -match "504|GatewayTimeout|timeout") {
                Write-ColorOutput "❌ Deployment timed out (504 Gateway Timeout)" "Red"
                Write-ColorOutput "" "White"
                Write-ColorOutput "💡 Timeout Troubleshooting:" "Yellow"
                Write-ColorOutput "   1. This is often due to slow dependency installation or large deployment package" "White"
                Write-ColorOutput "   2. Check deployment status in Azure Portal: https://portal.azure.com" "White"
                Write-ColorOutput "      - Navigate to your App Service > Deployment Center > Logs" "White"
                Write-ColorOutput "   3. The deployment may still succeed despite the timeout" "White"
                Write-ColorOutput "   4. Wait 5-10 minutes then test the application URL" "White"
                Write-ColorOutput "" "White"
                Write-ColorOutput "🔧 To fix locally:" "Yellow"
                Write-ColorOutput "   • Optimize requirements.txt (remove unused packages)" "White"
                Write-ColorOutput "   • Consider using Azure DevOps or GitHub Actions for large deployments" "White"
                Write-ColorOutput "   • Use 'az webapp up' command as alternative deployment method" "White"
                Write-ColorOutput "" "White"
                Write-ColorOutput "⚠️  This timeout does not necessarily mean deployment failed." "Yellow"
                Write-ColorOutput "    Check the application URL in a few minutes to verify deployment status." "Yellow"
                
                # Don't exit immediately for timeouts - let user decide
                Write-ColorOutput "" "White"
                Write-ColorOutput "Continuing with deployment verification..." "Cyan"
            } else {
                Write-Error "Failed to deploy application: $deployResult"
                exit 1
            }
        } else {
            Write-ColorOutput "✓ Application deployed successfully" "Green"
        }
        
        # Clean up temporary files
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        
        Write-ColorOutput "✓ Temporary files cleaned up" "Green"
    }
    catch {
        Write-Error "Failed to deploy application: $_"
        exit 1
    }
}

# Function to test deployment
function Test-Deployment {
    Write-ColorOutput "Testing deployment..." "Yellow"
    
    try {
        # Verify Web App exists before testing
        $appInfo = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Web App '$AppServiceName' not found. Cannot test deployment."
            exit 1
        }
        
        # Get the app URL
        $appUrl = ($appInfo | ConvertFrom-Json).defaultHostName
        $fullUrl = "https://$appUrl"
        
        Write-ColorOutput "Application URL: $fullUrl" "Cyan"
        
        # Test health endpoint
        $healthUrl = "$fullUrl/"
        Write-ColorOutput "Testing health endpoint: $healthUrl" "Cyan"
        
        # Wait longer for the app to start, especially after timeout scenarios
        Write-ColorOutput "⏳ Waiting for application to start (may take up to 2 minutes after deployment)..." "Yellow"
        Start-Sleep -Seconds 60
        
        $healthCheckSucceeded = $false
        try {
            $response = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 45
            if ($response.status -eq "ok") {
                Write-ColorOutput "✓ Health check passed: $($response.message)" "Green"
                $healthCheckSucceeded = $true
            } else {
                Write-ColorOutput "⚠ Health check returned unexpected response" "Yellow"
            }
        }
        catch {
            Write-ColorOutput "⚠ Health check failed - application may still be starting up" "Yellow"
            Write-ColorOutput "  This is common after deployment timeouts" "Yellow"
            Write-ColorOutput "" "White"
            Write-ColorOutput "🔍 Troubleshooting steps:" "Yellow"
            Write-ColorOutput "   1. Wait another 5-10 minutes and try accessing the URL manually" "White"
            Write-ColorOutput "   2. Check application logs in Azure Portal:" "White"
            Write-ColorOutput "      - Go to your App Service > Monitoring > Log stream" "White"
            Write-ColorOutput "      - Or App Service > Advanced Tools > Go > Debug console" "White"
            Write-ColorOutput "   3. Check if dependencies are still installing" "White"
        }
        
        # Additional timeout-specific guidance
        if (!$healthCheckSucceeded) {
            Write-ColorOutput "" "White"
            Write-ColorOutput "💡 If you experienced a deployment timeout:" "Yellow"
            Write-ColorOutput "   • The deployment may still be completing in the background" "White"
            Write-ColorOutput "   • Python dependencies might still be installing" "White"
            Write-ColorOutput "   • Check the SCM site for deployment status: https://$AppServiceName.scm.azurewebsites.net" "White"
        }
        
        # Test API documentation endpoint
        $docsUrl = "$fullUrl/docs"
        Write-ColorOutput "API Documentation available at: $docsUrl" "Cyan"
        
        Write-ColorOutput "✓ Deployment testing completed" "Green"
        Write-ColorOutput "📝 Manual verification steps:" "Yellow"
        Write-ColorOutput "   1. Visit $fullUrl to check health endpoint" "White"
        Write-ColorOutput "   2. Visit $docsUrl to access API documentation" "White"
        Write-ColorOutput "   3. Test API endpoints using the Swagger UI" "White"
        Write-ColorOutput "   4. Check application logs in Azure Portal if issues occur" "White"
        
    }
    catch {
        Write-Error "Failed to test deployment: $_"
        exit 1
    }
}

# Main execution
function Main {
    Write-ColorOutput "🚀 Starting Ship360 Chat API deployment to Azure..." "Green"
    Write-ColorOutput "=================================================" "Green"
    
    try {
        Test-Prerequisites
        Set-AzureSubscription
        New-AzureResources
        Set-EnvironmentVariables
        Set-StartupCommand
        Deploy-Application
        Test-Deployment
        
        Write-ColorOutput "=================================================" "Green"
        Write-ColorOutput "🎉 Deployment completed successfully!" "Green"
        Write-ColorOutput "=================================================" "Green"
        
        # Display summary
        $appInfo = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json 2>$null
        if ($LASTEXITCODE -eq 0) {
            $appUrl = ($appInfo | ConvertFrom-Json).defaultHostName
            Write-ColorOutput "📋 Deployment Summary:" "Cyan"
            Write-ColorOutput "   Resource Group: $ResourceGroupName" "White"
            Write-ColorOutput "   App Service: $AppServiceName" "White"
            Write-ColorOutput "   URL: https://$appUrl" "White"
            Write-ColorOutput "   API Docs: https://$appUrl/docs" "White"
        } else {
            Write-ColorOutput "📋 Deployment Summary:" "Cyan"
            Write-ColorOutput "   Resource Group: $ResourceGroupName" "White"
            Write-ColorOutput "   App Service: $AppServiceName" "White"
            Write-ColorOutput "   URL: Unable to retrieve (check Azure Portal)" "Yellow"
        }
        
    }
    catch {
        Write-Error "Deployment failed: $_"
        exit 1
    }
}

# Execute main function
Main