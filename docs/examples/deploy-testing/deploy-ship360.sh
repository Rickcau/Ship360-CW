#!/bin/bash

# Ship360 Chat API Azure Deployment Wrapper Script
# This script provides a bash interface to the PowerShell deployment script

set -e

# Default values
LOCATION="eastus"
PRICING_TIER="B1"
SKIP_RESOURCE_CREATION=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 -g RESOURCE_GROUP -n APP_NAME -e ENV_FILE [OPTIONS]"
    echo
    echo "Required parameters:"
    echo "  -g, --resource-group    Azure Resource Group name"
    echo "  -n, --app-name          Azure App Service name"  
    echo "  -e, --env-file          Path to environment variables file"
    echo
    echo "Optional parameters:"
    echo "  -l, --location          Azure region (default: eastus)"
    echo "  -p, --plan-name         App Service Plan name (default: auto-generated)"
    echo "  -t, --pricing-tier      Pricing tier (default: B1)"
    echo "  -s, --subscription      Azure subscription ID"
    echo "  -r, --source-path       Path to source code (default: ../../../ship360-chat-api)"
    echo "  --skip-resources        Skip creating Azure resources"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -g rg-ship360-dev -n app-ship360-dev -e ./ship360.env"
    echo "  $0 -g rg-ship360-prod -n app-ship360-prod -e ./ship360-prod.env -l westus2 -t P1v2"
}

# Function to check prerequisites
check_prerequisites() {
    print_color $YELLOW "Checking prerequisites..."
    
    # Check if PowerShell is available
    if ! command -v pwsh &> /dev/null; then
        print_color $RED "❌ PowerShell (pwsh) is not installed or not in PATH"
        print_color $YELLOW "Please install PowerShell Core 7+ and try again"
        print_color $CYAN "Installation: https://github.com/PowerShell/PowerShell#get-powershell"
        exit 1
    fi
    
    # Check if Azure CLI is available
    if ! command -v az &> /dev/null; then
        print_color $RED "❌ Azure CLI is not installed or not in PATH"
        print_color $YELLOW "Please install Azure CLI and try again"
        print_color $CYAN "Installation: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if deployment script exists
    if [ ! -f "./Deploy-Ship360ChatAPI.ps1" ]; then
        print_color $RED "❌ Deploy-Ship360ChatAPI.ps1 not found in current directory"
        exit 1
    fi
    
    print_color $GREEN "✓ All prerequisites met"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -n|--app-name)
            APP_NAME="$2"
            shift 2
            ;;
        -e|--env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -p|--plan-name)
            PLAN_NAME="$2"
            shift 2
            ;;
        -t|--pricing-tier)
            PRICING_TIER="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        -r|--source-path)
            SOURCE_PATH="$2"
            shift 2
            ;;
        --skip-resources)
            SKIP_RESOURCE_CREATION=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_color $RED "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ] || [ -z "$APP_NAME" ] || [ -z "$ENV_FILE" ]; then
    print_color $RED "❌ Missing required parameters"
    show_usage
    exit 1
fi

# Check prerequisites
check_prerequisites

# Build PowerShell command
print_color $GREEN "🚀 Starting Ship360 Chat API deployment..."
print_color $CYAN "Resource Group: $RESOURCE_GROUP"
print_color $CYAN "App Service: $APP_NAME"
print_color $CYAN "Environment File: $ENV_FILE"
print_color $CYAN "Location: $LOCATION"

# Build PowerShell parameters
PS_PARAMS="-ResourceGroupName '$RESOURCE_GROUP' -AppServiceName '$APP_NAME' -EnvironmentFile '$ENV_FILE' -Location '$LOCATION' -PricingTier '$PRICING_TIER'"

if [ -n "$PLAN_NAME" ]; then
    PS_PARAMS="$PS_PARAMS -AppServicePlanName '$PLAN_NAME'"
fi

if [ -n "$SUBSCRIPTION" ]; then
    PS_PARAMS="$PS_PARAMS -SubscriptionId '$SUBSCRIPTION'"
fi

if [ -n "$SOURCE_PATH" ]; then
    PS_PARAMS="$PS_PARAMS -SourcePath '$SOURCE_PATH'"
fi

if [ "$SKIP_RESOURCE_CREATION" = true ]; then
    PS_PARAMS="$PS_PARAMS -SkipResourceCreation"
fi

# Execute PowerShell deployment script
print_color $YELLOW "Executing deployment script..."
eval "pwsh -Command \"./Deploy-Ship360ChatAPI.ps1 $PS_PARAMS\""

# Check exit code
if [ $? -eq 0 ]; then
    print_color $GREEN "🎉 Deployment completed successfully!"
else
    print_color $RED "❌ Deployment failed!"
    exit 1
fi