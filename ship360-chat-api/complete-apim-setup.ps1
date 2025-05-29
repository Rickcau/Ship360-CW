# Complete APIM Configuration Script
# Run this script AFTER APIM provisioning is complete (status = "Succeeded")

param(
    [switch]$CheckStatus,
    [switch]$ImportAPI,
    [switch]$RestrictIPs,
    [switch]$GetInfo,
    [switch]$FullSetup
)

$RESOURCE_GROUP = "rg-ship360-chat-api"
$APIM_NAME = "apim-ship360-chat"
$CONTAINER_APP_NAME = "ship360-chat-api"
$API_NAME = "ship360-chat-api"
$API_PATH = "ship360-chat"
$PRODUCT_ID = "ship360-chat-product"
$SUBSCRIPTION_ID = "ship360-chat-subscription"

function Check-APIMStatus {
    Write-Host "=== Checking APIM Status ===" -ForegroundColor Green
    $status = az apim show --name $APIM_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" --output tsv
    Write-Host "APIM Status: $status" -ForegroundColor Cyan
    
    if ($status -eq "Succeeded") {
        Write-Host "✅ APIM is ready for configuration!" -ForegroundColor Green
        return $true
    } elseif ($status -eq "InProgress" -or $status -eq "Activating") {
        Write-Host "⏳ APIM is still provisioning. Please wait..." -ForegroundColor Yellow
        return $false
    } else {
        Write-Host "❌ APIM Status: $status" -ForegroundColor Red
        return $false
    }
}

function Import-ContainerAppAPI {
    Write-Host "=== Importing Container App API into APIM ===" -ForegroundColor Green
    
    # Get Container App URL
    $containerAppUrl = az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" --output tsv
    if (!$containerAppUrl) {
        Write-Host "❌ Could not get Container App URL" -ForegroundColor Red
        return
    }
    
    Write-Host "Container App URL: https://$containerAppUrl" -ForegroundColor Cyan
    
    # Import API from OpenAPI specification
    Write-Host "Importing API..." -ForegroundColor Yellow
    az apim api import `
        --resource-group $RESOURCE_GROUP `
        --service-name $APIM_NAME `
        --api-id $API_NAME `
        --path $API_PATH `
        --display-name "Ship360 Chat API" `
        --description "Ship360 Chat API powered by Azure OpenAI" `
        --specification-url "https://$containerAppUrl/openapi.json" `
        --specification-format OpenApi `
        --service-url "https://$containerAppUrl"
    
    # Create product
    Write-Host "Creating API product..." -ForegroundColor Yellow
    az apim product create `
        --resource-group $RESOURCE_GROUP `
        --service-name $APIM_NAME `
        --product-id $PRODUCT_ID `
        --product-name "Ship360 Chat API" `
        --description "Ship360 Chat API Product" `
        --subscription-required true `
        --approval-required false `
        --state published
    
    # Add API to product
    Write-Host "Adding API to product..." -ForegroundColor Yellow
    az apim product api add `
        --resource-group $RESOURCE_GROUP `
        --service-name $APIM_NAME `
        --product-id $PRODUCT_ID `
        --api-id $API_NAME
    
    # Create subscription
    Write-Host "Creating subscription..." -ForegroundColor Yellow
    az apim product subscription create `
        --resource-group $RESOURCE_GROUP `
        --service-name $APIM_NAME `
        --product-id $PRODUCT_ID `
        --subscription-id $SUBSCRIPTION_ID `
        --name "Ship360 Chat API Subscription" `
        --state active
    
    Write-Host "✅ API imported successfully!" -ForegroundColor Green
}

function Set-IPRestrictions {
    Write-Host "=== Setting IP Restrictions ===" -ForegroundColor Green
    
    # Get APIM IP addresses
    $apimIPs = az apim show --name $APIM_NAME --resource-group $RESOURCE_GROUP --query "publicIPAddresses" --output tsv
    if (!$apimIPs) {
        Write-Host "❌ Could not get APIM IP addresses" -ForegroundColor Red
        return
    }
    
    Write-Host "APIM Public IPs: $apimIPs" -ForegroundColor Cyan
    
    # Apply IP restrictions to Container App
    foreach ($ip in $apimIPs.Split(' ')) {
        if ($ip.Trim()) {
            Write-Host "Adding IP restriction for: $ip" -ForegroundColor Yellow
            az containerapp ingress access-restriction set `
                --name $CONTAINER_APP_NAME `
                --resource-group $RESOURCE_GROUP `
                --rule-name "apim-access-$($ip.Replace('.', '-'))" `
                --ip-address "$ip/32" `
                --action Allow
        }
    }
    
    Write-Host "✅ IP restrictions applied!" -ForegroundColor Green
    Write-Host "Container App now only accepts traffic from APIM" -ForegroundColor Cyan
}

function Get-APIMInfo {
    Write-Host "=== APIM Configuration Info ===" -ForegroundColor Green
    
    $gatewayUrl = az apim show --name $APIM_NAME --resource-group $RESOURCE_GROUP --query "gatewayUrl" --output tsv
    $subscriptionKey = az apim product subscription show --resource-group $RESOURCE_GROUP --service-name $APIM_NAME --product-id $PRODUCT_ID --subscription-id $SUBSCRIPTION_ID --query "primaryKey" --output tsv
    
    Write-Host ""
    Write-Host "🌐 APIM Gateway URLs:" -ForegroundColor Blue
    Write-Host "   Gateway URL: $gatewayUrl" -ForegroundColor Cyan
    Write-Host "   API URL: $gatewayUrl/$API_PATH" -ForegroundColor Cyan
    Write-Host "   API Docs: $gatewayUrl/$API_PATH/docs" -ForegroundColor Cyan
    Write-Host "   Health Check: $gatewayUrl/$API_PATH/" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "🔑 Subscription Key:" -ForegroundColor Blue
    Write-Host "   Key: $subscriptionKey" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "📋 Test Commands:" -ForegroundColor Blue
    Write-Host "   curl -H `"Ocp-Apim-Subscription-Key: $subscriptionKey`" $gatewayUrl/$API_PATH/" -ForegroundColor White
    
    Write-Host ""
    Write-Host "⚠️  Remember to include the 'Ocp-Apim-Subscription-Key' header in all API requests!" -ForegroundColor Yellow
}

# Main execution logic
if ($CheckStatus) {
    Check-APIMStatus
} elseif ($ImportAPI) {
    if (Check-APIMStatus) {
        Import-ContainerAppAPI
    }
} elseif ($RestrictIPs) {
    if (Check-APIMStatus) {
        Set-IPRestrictions
    }
} elseif ($GetInfo) {
    if (Check-APIMStatus) {
        Get-APIMInfo
    }
} elseif ($FullSetup) {
    if (Check-APIMStatus) {
        Import-ContainerAppAPI
        Set-IPRestrictions
        Get-APIMInfo
        Write-Host ""
        Write-Host "🎉 APIM deployment completed successfully!" -ForegroundColor Green
    }
} else {
    Write-Host "=== APIM Configuration Script ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Blue
    Write-Host "  .\complete-apim-setup.ps1 -CheckStatus      # Check if APIM is ready"
    Write-Host "  .\complete-apim-setup.ps1 -ImportAPI        # Import Container App API"
    Write-Host "  .\complete-apim-setup.ps1 -RestrictIPs      # Apply IP restrictions"
    Write-Host "  .\complete-apim-setup.ps1 -GetInfo          # Get APIM URLs and keys"
    Write-Host "  .\complete-apim-setup.ps1 -FullSetup        # Complete all steps"
    Write-Host ""
    Write-Host "Recommended: Wait for APIM provisioning to complete, then run:" -ForegroundColor Yellow
    Write-Host "  .\complete-apim-setup.ps1 -FullSetup" -ForegroundColor Cyan
}
