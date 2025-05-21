# Variables
$resourceGroup = "myShip360ResourceGroup"
$appServicePlan = "myShip360AppServicePlan" 
$webAppName = "myShip360FastApiApp"
$location = "centralus"
$pythonVersion = "3.12"

# Change to the project root if not already there
Set-Location "C:\Users\rickcau\source\repos\Ship360-CW\ship360-chat-api"

# 1. Create Resource Group (if it doesn't exist)
az group create --name $resourceGroup --location $location

# 2. Create App Service Plan (if it doesn't exist)
az appservice plan create --name $appServicePlan --resource-group $resourceGroup --sku B1 --is-linux

# 3. Create Web App with Python runtime (if it doesn't exist)
az webapp create --resource-group $resourceGroup --plan $appServicePlan --name $webAppName --runtime "PYTHON:$pythonVersion"

# 4. Zip the contents of the app directory AND the main.py file
$zipPath = ".\app.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }

# Create a temporary directory to organize files
$tempDir = ".\temp_deploy"
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir
New-Item -ItemType Directory -Path "$tempDir\app"

# Copy main.py to the temp root
Copy-Item -Path .\main.py -Destination $tempDir
Copy-Item -Path .\requirements.txt -Destination $tempDir -ErrorAction SilentlyContinue

# Copy app directory contents to temp/app
Copy-Item -Path .\app\* -Destination "$tempDir\app" -Recurse

# Zip the temp directory
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath

# Clean up temp directory
Remove-Item -Recurse -Force $tempDir

# 5. Deploy the zip to Azure App Service
az webapp deploy --resource-group $resourceGroup --name $webAppName --src-path $zipPath --type zip

# 6. Set the startup command for FastAPI
$startupCommand = "gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app"
az webapp config set --resource-group $resourceGroup --name $webAppName --startup-command $startupCommand

# 7. Add PYTHONPATH setting
az webapp config appsettings set --name $webAppName --resource-group $resourceGroup --settings PYTHONPATH=/home/site/wwwroot

# 8. Make sure dependencies are installed during deployment
az webapp config appsettings set --name $webAppName --resource-group $resourceGroup --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true

Write-Host "Deployment complete! Your FastAPI app should now be running on Azure App Service."
