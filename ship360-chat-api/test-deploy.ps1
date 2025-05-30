# Create the resources manually
az group create --name rg-ship360-dev2 --location centralus

az appservice plan create `
  --name ship360-plan2 `
  --resource-group rg-ship360-dev2 `
  --location centralus `
  --sku B2 `
  --is-linux

az webapp create `
  --name app-ship360-chat-dev2 `
  --resource-group rg-ship360-dev2 `
  --plan ship360-plan2 `
  --runtime "PYTHON:3.12"

# Enable build automation to install packages from requirements.txt
az webapp config appsettings set `
  --name app-ship360-chat-dev2 `
  --resource-group rg-ship360-dev2 `
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true

# Create ZIP excluding venv and other unnecessary files
$tempDir = ".\temp-deploy"
# Remove temp directory if it exists from previous run
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force
Copy-Item -Path ".\*" -Destination $tempDir -Recurse -Exclude "venv", "__pycache__", "*.pyc", ".git", ".vscode", "tests", "*.zip", "temp-deploy"
Compress-Archive -Path "$tempDir\*" -DestinationPath ".\ship360-deploy.zip" -Force
Remove-Item -Path $tempDir -Recurse -Force

# Deploy the ZIP with build automation
az webapp deployment source config-zip `
  --name app-ship360-chat-dev2 `
  --resource-group rg-ship360-dev2 `
  --src ".\ship360-deploy.zip"

# Configure FastAPI startup command
az webapp config set `
  --name app-ship360-chat-dev2 `
  --resource-group rg-ship360-dev2 `
  --startup-file "python -m gunicorn app.main:app -w 1 -k uvicorn.workers.UvicornWorker --bind=0.0.0.0:`$PORT --timeout=120 --log-level=info --access-logfile=- --error-logfile=-"

# Read environment variables from .env file
$envFilePath = ".\.env"
$envSettings = @()

# Add PORT setting first (not in .env file)
$envSettings += "PORT=8000"

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
          --name app-ship360-chat-dev2 `
          --resource-group rg-ship360-dev2 `
          --settings $envSettings
        Write-Host "Environment variables configured successfully!"
    } else {
        Write-Host "No environment variables found in .env file"
    }
} else {
    Write-Host "Warning: .env file not found at $envFilePath"
    # Still set PORT even if .env file doesn't exist
    az webapp config appsettings set `
      --name app-ship360-chat-dev2 `
      --resource-group rg-ship360-dev2 `
      --settings "PORT=8000"
}