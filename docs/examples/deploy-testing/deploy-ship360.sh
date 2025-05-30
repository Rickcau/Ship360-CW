#!/bin/bash
# Ship360 Chat API - Deployment Script (Bash version)
# This script provides a simple wrapper around the PowerShell deployment script

set -e

# Check if PowerShell is installed
if ! command -v pwsh &> /dev/null; then
    echo "❌ PowerShell (pwsh) is not installed or not in PATH"
    echo "Please install PowerShell Core to use this script:"
    echo "  - Windows: https://aka.ms/powershell-release"
    echo "  - macOS: brew install --cask powershell"
    echo "  - Linux: https://aka.ms/powershell-release"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed or not in PATH"
    echo "Please install Azure CLI to use this script:"
    echo "  - Windows: https://aka.ms/installazurecliwindows"
    echo "  - macOS: brew install azure-cli"
    echo "  - Linux: https://aka.ms/installazureclilinux"
    exit 1
fi

# Default values
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ship360-dev}"
APP_SERVICE_NAME="${APP_SERVICE_NAME:-app-ship360-chat-dev}"
LOCATION="${LOCATION:-eastus}"
ENV_FILE="${ENV_FILE:-./ship360-sample.env}"
SOURCE_PATH="${SOURCE_PATH:-../../../ship360-chat-api}"

# Display help if no arguments or help flag
if [ $# -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Ship360 Chat API - Deployment Script (Bash version)"
    echo ""
    echo "Usage:"
    echo "  $0 [options]"
    echo ""
    echo "Options:"
    echo "  -g, --resource-group    Resource group name (default: $RESOURCE_GROUP)"
    echo "  -n, --name              App Service name (default: $APP_SERVICE_NAME)"
    echo "  -l, --location          Azure region (default: $LOCATION)"
    echo "  -e, --env-file          Path to environment file (default: $ENV_FILE)"
    echo "  -s, --source            Path to source code (default: $SOURCE_PATH)"
    echo "  -d, --debug             Enable debug mode"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --resource-group rg-ship360-prod --name app-ship360-chat-prod --location westus2"
    exit 0
fi

# Parse arguments
DEBUG_MODE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -n|--name)
            APP_SERVICE_NAME="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -e|--env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE_PATH="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG_MODE="-DebugMode"
            shift
            ;;
        *)
            echo "❌ Unknown option: $1"
            exit 1
            ;;
    esac
done

# Construct the PowerShell command
PWSH_CMD="pwsh -File ./Deploy-Ship360ChatAPI.ps1 \
    -ResourceGroupName \"$RESOURCE_GROUP\" \
    -AppServiceName \"$APP_SERVICE_NAME\" \
    -Location \"$LOCATION\" \
    -EnvironmentFile \"$ENV_FILE\" \
    -SourcePath \"$SOURCE_PATH\" \
    $DEBUG_MODE"

# Execute the PowerShell script
echo "🚀 Executing deployment script with the following parameters:"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   App Service: $APP_SERVICE_NAME"
echo "   Location: $LOCATION"
echo "   Environment File: $ENV_FILE"
echo "   Source Path: $SOURCE_PATH"
echo ""
echo "Starting deployment..."
echo "------------------------"

eval $PWSH_CMD