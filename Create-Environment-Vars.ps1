# RDC: Working 5/20/2025
$resourceGroup = "myShip360ResourceGroup" 
$appServicePlan = "myShip360AppServicePlan"  
$webAppName = "myShip360FastApiApp" 
$location = "centralus"   

# Function to set environment variables from .env file
function Set-EnvironmentVariables {
    param (
        [string]$ResourceGroupName,
        [string]$WebAppName
    )

    Write-Host "Setting environment variables..." -ForegroundColor Yellow
    
    $envFilePath = ".\ship360-chat-api\.env"
    if (-not (Test-Path $envFilePath)) {
        $envFilePath = ".\.env"
        if (-not (Test-Path $envFilePath)) {
            Write-Host "Warning: .env file not found. Environment variables will not be set." -ForegroundColor Yellow
            return
        }
    }
    
    $envVars = Get-Content $envFilePath | Where-Object { $_ -match "^[^#].*=.*" } | ForEach-Object {
        $parts = $_ -split "=", 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim('"', "'", ' ')
        "$key=$value"
    }
    
    if ($envVars.Count -gt 0) {
        # Check if the web app exists before trying to set environment variables
        $webAppExists = az webapp list --resource-group $ResourceGroupName --query "[?name=='$WebAppName']" --output tsv
        if (-not $webAppExists) {
            Write-Host "❌ Cannot set environment variables - Web App $WebAppName not found" -ForegroundColor Red
            return
        }
        
        # Set environment variables
        $result = az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings $envVars 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to set environment variables. Error: $result" -ForegroundColor Red
            return
        }
        Write-Host "✅ Environment variables set" -ForegroundColor Green
    } else {
        Write-Host "Warning: No environment variables found in .env file" -ForegroundColor Yellow
    }
}

try {
    Write-Host "✅ Trying to set environment variables." -ForegroundColor Yellow
    # Pass the global variables to the function
    Set-EnvironmentVariables -ResourceGroupName $resourceGroup -WebAppName $webAppName
} catch {
    Write-Host "❌ Error setting environment variables: $_" -ForegroundColor Red
}