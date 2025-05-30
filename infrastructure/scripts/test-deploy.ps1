# Configuration variables
$resourceGroupName = "rg-ship360-dev3"
$location = "centralus"
$appServicePlanName = "ship360-plan3"
$webAppName = "app-ship360-chat-dev3"
$skuName = "B2"
$pythonVersion = "PYTHON:3.12"
$port = "8000"

# Get the script's directory and project root paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$apiDir = Join-Path -Path $projectRoot -ChildPath "ship360-chat-api"

# Create the resources manually
az group create --name $resourceGroupName --location $location

az appservice plan create `
  --name $appServicePlanName `
  --resource-group $resourceGroupName `
  --location $location `
  --sku $skuName `
  --is-linux

az webapp create `
  --name $webAppName `
  --resource-group $resourceGroupName `
  --plan $appServicePlanName `
  --runtime $pythonVersion

# Enable build automation to install packages from requirements.txt
az webapp config appsettings set `
  --name $webAppName `
  --resource-group $resourceGroupName `
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true

# Create ZIP excluding venv and other unnecessary files
$tempDir = Join-Path -Path $scriptDir -ChildPath "temp-deploy"
# Remove temp directory if it exists from previous run
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force
Copy-Item -Path "$apiDir\*" -Destination $tempDir -Recurse -Exclude "venv", "__pycache__", "*.pyc", ".git", ".vscode", "tests", "*.zip", "temp-deploy"
$zipPath = Join-Path -Path $apiDir -ChildPath "ship360-deploy.zip"
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
Remove-Item -Path $tempDir -Recurse -Force

# Deploy the ZIP with build automation
az webapp deployment source config-zip `
  --name $webAppName `
  --resource-group $resourceGroupName `
  --src $zipPath

# Configure FastAPI startup command
az webapp config set `
  --name $webAppName `
  --resource-group $resourceGroupName `
  --startup-file "python -m gunicorn app.main:app -w 1 -k uvicorn.workers.UvicornWorker --bind=0.0.0.0:`$PORT --timeout=120 --log-level=info --access-logfile=- --error-logfile=-"

# Read environment variables from .env file
$envFilePath = Join-Path -Path $apiDir -ChildPath ".env"
$envSettings = @()

# Add PORT setting first (not in .env file)
$envSettings += "PORT=$port"

# Check if .env file exists
if (Test-Path $envFilePath) {
    Write-Host "Reading environment variables from $envFilePath"
    
    # Read .env file and parse each line
    Get-Content $envFilePath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ($line -and !$line.StartsWith("#")) {
            # Check if line contains = sign
            if ($line -match "^([^=]+)=(.*)$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                
                # Add to settings array
                $envSettings += "$key=$value"
                Write-Host "Added: $key"
            }
        }
    }
    
    # Apply all environment variables at once
    if ($envSettings.Count -gt 0) {
        Write-Host "Setting $($envSettings.Count) environment variables..."
        az webapp config appsettings set `
          --name $webAppName `
          --resource-group $resourceGroupName `
          --settings $envSettings
        Write-Host "Environment variables configured successfully!"
    } else {
        Write-Host "No environment variables found in .env file"
    }
} else {
    Write-Host "Warning: .env file not found at $envFilePath"
    # Still set PORT even if .env file doesn't exist
    az webapp config appsettings set `
      --name $webAppName `
      --resource-group $resourceGroupName `
      --settings "PORT=$port"
}