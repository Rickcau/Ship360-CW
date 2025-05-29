# Ship360 Chat API - Simple Makefile

# Generate a random 3-character suffix for uniqueness
# This creates a suffix like "abc" from random lowercase letters
# Works on both Linux and macOS
RANDOM_SUFFIX := $(shell if [ -r /dev/urandom ]; then LC_ALL=C tr -dc 'a-z' < /dev/urandom | head -c 3; else python3 -c "import random; print(''.join(random.choices('abcdefghijklmnopqrstuvwxyz', k=3)))"; fi)

# Azure Configuration - Allow overrides via command line or environment
# Usage: make deploy-containerapp RESOURCE_GROUP=rg-myapp-prod
# Or: RESOURCE_GROUP=rg-myapp-prod make deploy-containerapp
RESOURCE_GROUP ?= $(or $(AZURE_RESOURCE_GROUP),rg-ship360-chat-api-$(RANDOM_SUFFIX))
LOCATION ?= $(or $(AZURE_LOCATION),eastus)
ACR_NAME ?= $(or $(AZURE_ACR_NAME),acrship360chat$(RANDOM_SUFFIX))
CONTAINER_APP_ENV ?= $(or $(AZURE_CONTAINER_APP_ENV),ship360-chat-env-$(RANDOM_SUFFIX))
CONTAINER_APP_NAME ?= $(or $(AZURE_CONTAINER_APP_NAME),ship360-chat-api-$(RANDOM_SUFFIX))
IMAGE_NAME := ship360-chat-api
IMAGE_TAG := latest

# APIM Configuration
APIM_NAME ?= $(or $(AZURE_APIM_NAME),apim-ship360-chat-$(RANDOM_SUFFIX))
APIM_SKU ?= $(or $(AZURE_APIM_SKU),Standard)
APIM_PUBLISHER_NAME ?= $(or $(AZURE_APIM_PUBLISHER_NAME),Ship360)
APIM_PUBLISHER_EMAIL ?= $(or $(AZURE_APIM_PUBLISHER_EMAIL),admin@ship360.com)
APIM_API_NAME ?= $(or $(AZURE_APIM_API_NAME),ship360-chat-api)
APIM_API_PATH ?= $(or $(AZURE_APIM_API_PATH),ship360-chat)

# Load environment variables from .env file
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help
help: ## Show this help message
	@echo "Ship360 Chat API - Available Commands:"
	@echo ""
	@echo "$(YELLOW)Main Deployment Commands:$(NC)"
	@echo "  $(GREEN)deploy-containerapp  $(NC) Deploy solution with Container Apps only"
	@echo "  $(GREEN)deploy-with-apim     $(NC) Deploy solution with Container Apps and API Management"
	@echo "  $(GREEN)update-containerapp  $(NC) Update existing Container App deployment"
	@echo ""
	@echo "$(YELLOW)Usage Examples:$(NC)"
	@echo "  make deploy-containerapp"
	@echo "  make deploy-containerapp RESOURCE_GROUP=rg-myapp-prod"
	@echo "  make deploy-with-apim RESOURCE_GROUP=rg-myapp-prod LOCATION=westus"
	@echo "  RESOURCE_GROUP=rg-myapp-prod make update-containerapp"
	@echo ""
	@echo "$(YELLOW)Configurable Parameters:$(NC)"
	@echo "  RESOURCE_GROUP        Resource group name (default: $(RESOURCE_GROUP))"
	@echo "  LOCATION             Azure region (default: $(LOCATION))"
	@echo "  ACR_NAME             Container registry name (default: $(ACR_NAME))"
	@echo "  CONTAINER_APP_ENV    Container App environment (default: $(CONTAINER_APP_ENV))"
	@echo "  CONTAINER_APP_NAME   Container App name (default: $(CONTAINER_APP_NAME))"
	@echo ""
	@echo "$(YELLOW)Other Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -v "deploy-containerapp\|deploy-with-apim\|update-containerapp" | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

.PHONY: check-env
check-env: ## Check if .env file exists
	@if [ ! -f .env ]; then \
		echo "$(RED)Error: .env file not found!$(NC)"; \
		echo "$(YELLOW)Please copy .env.example to .env and fill in your values:$(NC)"; \
		echo "cp .env.example .env"; \
		exit 1; \
	fi
	@echo "$(GREEN).env file found$(NC)"

.PHONY: install
install: ## Install Python dependencies
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	pip install -r requirements.txt

.PHONY: dev
dev: check-env ## Run application in development mode
	@echo "$(GREEN)Starting development server...$(NC)"
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

.PHONY: test-local
test-local: check-env ## Test the API locally
	@echo "$(YELLOW)Testing local API...$(NC)"
	@echo "Starting server in background..."
	uvicorn app.main:app --host 0.0.0.0 --port 8000 &
	@sleep 5
	@echo "Testing health endpoint..."
	curl -f http://localhost:8000/health || echo "Health check failed"
	@echo "Stopping background server..."
	pkill -f "uvicorn app.main:app"

.PHONY: docker-build
docker-build: ## Build Docker image locally
	@echo "$(YELLOW)Building Docker image...$(NC)"
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

.PHONY: docker-run
docker-run: check-env docker-build ## Run Docker container locally
	@echo "$(GREEN)Running Docker container...$(NC)"
	docker run -d --name $(CONTAINER_APP_NAME)-local -p 8000:8000 --env-file .env $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "Container started. Test with: curl http://localhost:8000/health"
	@echo "View logs with: docker logs $(CONTAINER_APP_NAME)-local"
	@echo "Stop with: make docker-stop"

.PHONY: docker-stop
docker-stop: ## Stop local Docker container
	@echo "$(YELLOW)Stopping Docker container...$(NC)"
	docker stop $(CONTAINER_APP_NAME)-local || true
	docker rm $(CONTAINER_APP_NAME)-local || true

.PHONY: azure-login
azure-login: ## Login to Azure CLI
	@echo "$(YELLOW)Logging into Azure...$(NC)"
	az login

.PHONY: azure-setup
azure-setup: azure-login ## Create resource group and ACR
	@echo "$(YELLOW)Registering required Azure resource providers...$(NC)"
	az provider register --namespace Microsoft.ContainerRegistry --wait
	az provider register --namespace Microsoft.App --wait
	az provider register --namespace Microsoft.OperationalInsights --wait
	az provider register --namespace Microsoft.ApiManagement --wait
	@echo "$(YELLOW)Creating Azure resources...$(NC)"
	az group create --name $(RESOURCE_GROUP) --location $(LOCATION)
	az acr create --resource-group $(RESOURCE_GROUP) --name $(ACR_NAME) --sku Basic --admin-enabled true
	az containerapp env create --name $(CONTAINER_APP_ENV) --resource-group $(RESOURCE_GROUP) --location $(LOCATION)

.PHONY: azure-build
azure-build: check-env ## Build and push image to ACR
	@echo "$(YELLOW)Building and pushing image to ACR...$(NC)"
	az acr build --registry $(ACR_NAME) --image $(IMAGE_NAME):$(IMAGE_TAG) .

.PHONY: deploy-containerapp
deploy-containerapp: check-env ## Deploy solution with Container Apps only
	@echo "$(GREEN)Starting Container Apps deployment...$(NC)"
	@echo "$(YELLOW)Using resource names with suffix: $(RANDOM_SUFFIX)$(NC)"
	@echo "  Resource Group: $(RESOURCE_GROUP)"
	@echo "  ACR Name: $(ACR_NAME)"
	@echo "  Container App: $(CONTAINER_APP_NAME)"
	@echo "$(YELLOW)Logging into Azure...$(NC)"
	az login
	@echo "$(YELLOW)Registering required Azure resource providers...$(NC)"
	az provider register --namespace Microsoft.ContainerRegistry --wait
	az provider register --namespace Microsoft.App --wait
	az provider register --namespace Microsoft.OperationalInsights --wait
	@echo "$(YELLOW)Creating Azure resources...$(NC)"
	az group create --name $(RESOURCE_GROUP) --location $(LOCATION)
	az acr create --resource-group $(RESOURCE_GROUP) --name $(ACR_NAME) --sku Basic --admin-enabled true
	az containerapp env create --name $(CONTAINER_APP_ENV) --resource-group $(RESOURCE_GROUP) --location $(LOCATION)
	@echo "$(YELLOW)Building and pushing image to ACR...$(NC)"
	az acr build --registry $(ACR_NAME) --image $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "$(GREEN)Deploying to Azure Container Apps...$(NC)"
	@# Get ACR credentials and deploy in one command to ensure they're available
	@ACR_LOGIN_SERVER=$$(az acr show --name $(ACR_NAME) --query loginServer --output tsv | tr -d '\r') && \
	ACR_USERNAME=$$(az acr credential show --name $(ACR_NAME) --query username --output tsv | tr -d '\r') && \
	ACR_PASSWORD=$$(az acr credential show --name $(ACR_NAME) --query "passwords[0].value" --output tsv | tr -d '\r') && \
	az containerapp create \
		--name $(CONTAINER_APP_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--environment $(CONTAINER_APP_ENV) \
		--image "$$ACR_LOGIN_SERVER/$(IMAGE_NAME):$(IMAGE_TAG)" \
		--target-port 8000 \
		--ingress 'external' \
		--registry-server $$ACR_LOGIN_SERVER \
		--registry-username $$ACR_USERNAME \
		--registry-password $$ACR_PASSWORD \
		--cpu 0.5 \
		--memory 1.0 \
		--min-replicas 1 \
		--max-replicas 3 \
		--system-assigned \
		--env-vars \
			PROJECT_NAME="Chat API" \
			API_PREFIX="/api" \
			DEBUG="false" \
			ENVIRONMENT="production" \
			LOG_LEVEL="$(LOG_LEVEL)" \
			AZURE_OPENAI_API_KEY="$(AZURE_OPENAI_API_KEY)" \
			AZURE_OPENAI_ENDPOINT="$(AZURE_OPENAI_ENDPOINT)" \
			AZURE_OPENAI_API_VERSION="$(AZURE_OPENAI_API_VERSION)" \
			AZURE_OPENAI_CHAT_DEPLOYMENT_NAME="$(AZURE_OPENAI_CHAT_DEPLOYMENT_NAME)" \
			MASTER_AGENT_DEPLOYMENT="$(MASTER_AGENT_DEPLOYMENT)" \
			INTENT_AGENT_DEPLOYMENT="$(INTENT_AGENT_DEPLOYMENT)" \
			RATE_AGENT_DEPLOYMENT="$(RATE_AGENT_DEPLOYMENT)" \
			LABEL_AGENT_DEPLOYMENT="$(LABEL_AGENT_DEPLOYMENT)" \
			TRACKING_AGENT_DEPLOYMENT="$(TRACKING_AGENT_DEPLOYMENT)" \
			SP360_TOKEN_URL="$(SP360_TOKEN_URL)" \
			SP360_TOKEN_USERNAME="$(SP360_TOKEN_USERNAME)" \
			SP360_TOKEN_PASSWORD="$(SP360_TOKEN_PASSWORD)" \
			SP360_RATE_SHOP_URL="$(SP360_RATE_SHOP_URL)" \
			SP360_SHIPMENTS_URL="$(SP360_SHIPMENTS_URL)" \
			SP360_TRACKING_URL="$(SP360_TRACKING_URL)"
	@echo "$(GREEN)Deployment complete!$(NC)"
	@echo "$(GREEN)Container App URL:$(NC)"
	@az containerapp show \
		--name $(CONTAINER_APP_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--query properties.configuration.ingress.fqdn \
		--output tsv | xargs -I {} echo "https://{}"

.PHONY: deploy
deploy: deploy-containerapp ## Alias for deploy-containerapp

.PHONY: deploy-with-apim
deploy-with-apim: check-env ## Deploy solution with Container Apps and API Management
	@echo "$(GREEN)Starting deployment with Container Apps and API Management...$(NC)"
	
	@# First deploy Container App
	@make deploy-containerapp
	
	@# Create APIM instance
	@echo "$(YELLOW)Creating API Management instance...$(NC)"
	@echo "$(YELLOW)This may take 30-45 minutes to complete.$(NC)"
	
	@# Register API Management resource provider
	az provider register --namespace Microsoft.ApiManagement --wait
	
	@# Create APIM instance
	az apim create \
		--name $(APIM_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--location $(LOCATION) \
		--sku-name $(APIM_SKU) \
		--sku-capacity 1 \
		--publisher-name $(APIM_PUBLISHER_NAME) \
		--publisher-email $(APIM_PUBLISHER_EMAIL) \
		--no-wait
	
	@echo "$(YELLOW)APIM creation initiated. Waiting for provisioning...$(NC)"
	@while [ "$$(az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query provisioningState --output tsv 2>/dev/null || echo 'InProgress')" = "InProgress" ]; do \
		sleep 120; \
		echo "$(CYAN)APIM provisioning state: $$(az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query provisioningState --output tsv 2>/dev/null || echo 'InProgress')$(NC)"; \
	done
	
	@if [ "$$(az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query provisioningState --output tsv 2>/dev/null)" != "Succeeded" ]; then \
		echo "$(RED)APIM provisioning failed$(NC)"; \
		exit 1; \
	fi
	
	@# Import API
	@echo "$(YELLOW)Importing Container App API into APIM...$(NC)"
	@CONTAINER_APP_URL=$$(az containerapp show --name $(CONTAINER_APP_NAME) --resource-group $(RESOURCE_GROUP) --query properties.configuration.ingress.fqdn --output tsv | tr -d '\r') && \
	az apim api import \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_NAME) \
		--api-id $(APIM_API_NAME) \
		--path $(APIM_API_PATH) \
		--display-name "Ship360 Chat API" \
		--description "Ship360 Chat API powered by Azure OpenAI" \
		--specification-url "https://$$CONTAINER_APP_URL/openapi.json" \
		--specification-format OpenApi \
		--service-url "https://$$CONTAINER_APP_URL"
	
	@# Create product and subscription
	az apim product create \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_NAME) \
		--product-id "ship360-chat-product" \
		--product-name "Ship360 Chat API" \
		--description "Ship360 Chat API Product" \
		--subscription-required true \
		--approval-required false \
		--state published
	
	az apim product api add \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_NAME) \
		--product-id "ship360-chat-product" \
		--api-id $(APIM_API_NAME)
	
	az apim product subscription create \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_NAME) \
		--product-id "ship360-chat-product" \
		--subscription-id "ship360-chat-subscription" \
		--name "Ship360 Chat API Subscription" \
		--state active
	
	@# Show results
	@echo "$(GREEN)Deployment with APIM complete!$(NC)"
	@GATEWAY_URL=$$(az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query gatewayUrl --output tsv) && \
	echo "$(CYAN)APIM Gateway URL: $$GATEWAY_URL$(NC)" && \
	echo "$(CYAN)API URL: $$GATEWAY_URL/$(APIM_API_PATH)$(NC)"
	
	@# Get subscription key
	@SUBSCRIPTION_KEY=$$(az apim product subscription show --resource-group $(RESOURCE_GROUP) --service-name $(APIM_NAME) --product-id "ship360-chat-product" --subscription-id "ship360-chat-subscription" --query primaryKey --output tsv) && \
	echo "$(GREEN)Subscription Key: $$SUBSCRIPTION_KEY$(NC)" && \
	echo "$(YELLOW)Use this key in the 'Ocp-Apim-Subscription-Key' header for API calls.$(NC)"

.PHONY: deploy-all
deploy-all: deploy-with-apim ## Alias for deploy-with-apim

.PHONY: update-containerapp
update-containerapp: check-env ## Update existing Container App deployment
	@echo "$(YELLOW)Logging into Azure...$(NC)"
	az login
	@echo "$(YELLOW)Building and pushing image to ACR...$(NC)"
	az acr build --registry $(ACR_NAME) --image $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "$(GREEN)Updating Container App...$(NC)"
	@ACR_LOGIN_SERVER=$$(az acr show --name $(ACR_NAME) --query loginServer --output tsv | tr -d '\r') && \
	az containerapp update \
		--name $(CONTAINER_APP_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--image "$$ACR_LOGIN_SERVER/$(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "$(GREEN)Update complete!$(NC)"
	@echo "$(CYAN)Container App URL: https://$$(az containerapp show --name $(CONTAINER_APP_NAME) --resource-group $(RESOURCE_GROUP) --query properties.configuration.ingress.fqdn --output tsv)$(NC)"

.PHONY: update
update: update-containerapp ## Alias for update-containerapp

.PHONY: azure-logs
azure-logs: ## View Container App logs
	@echo "$(YELLOW)Fetching logs...$(NC)"
	az containerapp logs show \
		--name $(CONTAINER_APP_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--follow

.PHONY: azure-url
azure-url: ## Get Container App URL
	@echo "$(GREEN)Container App URL:$(NC)"
	@az containerapp show \
		--name $(CONTAINER_APP_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--query properties.configuration.ingress.fqdn \
		--output tsv | xargs -I {} echo "https://{}"

.PHONY: azure-status
azure-status: ## Check Container App status
	@echo "$(YELLOW)Container App Status:$(NC)"
	@az containerapp show \
		--name $(CONTAINER_APP_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--query properties.runningStatus \
		--output tsv

.PHONY: azure-scale
azure-scale: ## Scale Container App (usage: make azure-scale MIN=2 MAX=10)
	@echo "$(YELLOW)Scaling Container App...$(NC)"
	az containerapp update \
		--name $(CONTAINER_APP_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--min-replicas $(or $(MIN),1) \
		--max-replicas $(or $(MAX),3)

.PHONY: clean
clean: ## Clean local artifacts
	@echo "$(YELLOW)Cleaning up...$(NC)"
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	docker-stop || true

.PHONY: apim-setup
apim-setup: azure-login ## Create API Management instance
	@echo "$(YELLOW)Creating API Management instance...$(NC)"
	@echo "$(YELLOW)This may take 30-45 minutes to complete.$(NC)"
	az apim create \
		--name $(APIM_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--location $(LOCATION) \
		--sku-name $(APIM_SKU) \
		--sku-capacity 1 \
		--publisher-name $(APIM_PUBLISHER_NAME) \
		--publisher-email $(APIM_PUBLISHER_EMAIL) \
		--no-wait
	@echo "$(GREEN)APIM creation initiated. Check status with: az apim show -n $(APIM_NAME) -g $(RESOURCE_GROUP) --query provisioningState$(NC)"

.PHONY: apim-import-api
apim-import-api: ## Import Container App API into APIM
	@echo "$(YELLOW)Importing Container App API into APIM...$(NC)"
	@CONTAINER_APP_URL=$$(az containerapp show --name $(CONTAINER_APP_NAME) --resource-group $(RESOURCE_GROUP) --query properties.configuration.ingress.fqdn --output tsv | tr -d '\r') && \
	if [ -z "$$CONTAINER_APP_URL" ]; then \
		echo "$(RED)Error: Could not get Container App URL. Ensure the Container App is deployed.$(NC)"; \
		exit 1; \
	fi && \
	az apim api import \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_NAME) \
		--api-id $(APIM_API_NAME) \
		--path $(APIM_API_PATH) \
		--display-name "Ship360 Chat API" \
		--description "Ship360 Chat API powered by Azure OpenAI" \
		--specification-url "https://$$CONTAINER_APP_URL/openapi.json" \
		--specification-format OpenApi \
		--service-url "https://$$CONTAINER_APP_URL"
	@# Create a product for the API
	az apim product create \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_NAME) \
		--product-id "ship360-chat-product" \
		--product-name "Ship360 Chat API" \
		--description "Ship360 Chat API Product" \
		--subscription-required true \
		--approval-required false \
		--state published
	@# Add API to product
	az apim product api add \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_NAME) \
		--product-id "ship360-chat-product" \
		--api-id $(APIM_API_NAME)
	@# Create a subscription
	az apim product subscription create \
		--resource-group $(RESOURCE_GROUP) \
		--service-name $(APIM_NAME) \
		--product-id "ship360-chat-product" \
		--subscription-id "ship360-chat-subscription" \
		--name "Ship360 Chat API Subscription" \
		--state active
	@echo "$(GREEN)API imported successfully into APIM!$(NC)"
	@make apim-url

.PHONY: apim-get-ips
apim-get-ips: ## Get APIM outbound IP addresses
	@echo "$(YELLOW)Getting APIM outbound IP addresses...$(NC)"
	$(eval APIM_IPS := $(shell az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query "[publicIPAddresses, privateIPAddresses]" --output tsv))
	@echo "$(GREEN)APIM IP Addresses:$(NC)"
	@echo "$(APIM_IPS)"
	$(eval GATEWAY_URL := $(shell az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query gatewayUrl --output tsv))
	@echo "$(GREEN)APIM Gateway URL: $(GATEWAY_URL)$(NC)"

.PHONY: containerapp-restrict-ips
containerapp-restrict-ips: ## Restrict Container App access to APIM IPs only
	@echo "$(YELLOW)Restricting Container App access to APIM IPs only...$(NC)"
	$(eval APIM_PUBLIC_IPS := $(shell az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query "publicIPAddresses[]" --output tsv))
	@if [ -z "$(APIM_PUBLIC_IPS)" ]; then \
		echo "$(RED)Error: Could not get APIM IP addresses. Ensure APIM is provisioned.$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Found APIM IPs: $(APIM_PUBLIC_IPS)$(NC)"
	@for ip in $(APIM_PUBLIC_IPS); do \
		echo "$(YELLOW)Adding IP restriction for: $$ip$(NC)"; \
		az containerapp ingress access-restriction set \
			--name $(CONTAINER_APP_NAME) \
			--resource-group $(RESOURCE_GROUP) \
			--rule-name "apim-access" \
			--ip-address "$$ip/32" \
			--action Allow; \
	done
	@echo "$(GREEN)IP restrictions applied successfully!$(NC)"
	@echo "$(GREEN)Container App now only accepts traffic from APIM.$(NC)"

.PHONY: apim-deploy
apim-deploy: check-env ## Full APIM deployment with IP restrictions
	@echo "$(GREEN)Starting full APIM deployment...$(NC)"
	@# Ensure Container App is deployed first
	@echo "$(YELLOW)Checking Container App status...$(NC)"
	$(eval CONTAINER_APP_STATUS := $(shell az containerapp show --name $(CONTAINER_APP_NAME) --resource-group $(RESOURCE_GROUP) --query properties.runningStatus --output tsv 2>/dev/null || echo "NotFound"))
	@if [ "$(CONTAINER_APP_STATUS)" != "Running" ]; then \
		echo "$(YELLOW)Container App is not running. Deploying it first...$(NC)"; \
		make deploy; \
	fi
	@# Check if APIM exists, create if not
	$(eval APIM_EXISTS := $(shell az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query name --output tsv 2>/dev/null || echo ""))
	@if [ -z "$(APIM_EXISTS)" ]; then \
		echo "$(YELLOW)APIM instance not found. Creating it...$(NC)"; \
		make apim-setup; \
		echo "$(YELLOW)Waiting for APIM to be provisioned (this can take 30-45 minutes)...$(NC)"; \
		while [ "$$(az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query provisioningState --output tsv 2>/dev/null)" = "InProgress" ]; do \
			sleep 120; \
			echo "$(CYAN)APIM provisioning state: $$(az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query provisioningState --output tsv 2>/dev/null)$(NC)"; \
		done; \
		if [ "$$(az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query provisioningState --output tsv 2>/dev/null)" != "Succeeded" ]; then \
			echo "$(RED)APIM provisioning failed$(NC)"; \
			exit 1; \
		fi; \
	fi
	@# Import API
	@echo "$(YELLOW)Importing API into APIM...$(NC)"
	@make apim-import-api
	@# Apply IP restrictions
	@echo "$(YELLOW)Applying IP restrictions...$(NC)"
	@make containerapp-restrict-ips
	@echo "$(GREEN)APIM deployment complete!$(NC)"
	@make apim-url
	@# Show subscription key
	@echo "$(YELLOW)Getting subscription key...$(NC)"
	$(eval SUBSCRIPTION_KEY := $(shell az apim product subscription show --resource-group $(RESOURCE_GROUP) --service-name $(APIM_NAME) --product-id "ship360-chat-product" --subscription-id "ship360-chat-subscription" --query primaryKey --output tsv))
	@echo "$(GREEN)Subscription Key: $(SUBSCRIPTION_KEY)$(NC)"
	@echo "$(YELLOW)Use this key in the 'Ocp-Apim-Subscription-Key' header for API calls.$(NC)"

.PHONY: apim-url
apim-url: ## Get APIM gateway URL
	@echo "$(GREEN)APIM Gateway URLs:$(NC)"
	$(eval GATEWAY_URL := $(shell az apim show --name $(APIM_NAME) --resource-group $(RESOURCE_GROUP) --query gatewayUrl --output tsv))
	@echo "Gateway URL: $(GATEWAY_URL)"
	@echo "API URL: $(GATEWAY_URL)/$(APIM_API_PATH)"
	@echo "API Docs: $(GATEWAY_URL)/$(APIM_API_PATH)/docs"
	@echo "Health Check: $(GATEWAY_URL)/$(APIM_API_PATH)/"
	@echo "$(YELLOW)Remember to include the 'Ocp-Apim-Subscription-Key' header in your requests.$(NC)"

.PHONY: azure-delete
azure-delete: ## Delete all Azure resources
	@echo "$(RED)WARNING: This will delete all resources in $(RESOURCE_GROUP)$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		az group delete --name $(RESOURCE_GROUP) --yes --no-wait; \
		echo "$(YELLOW)Resource group deletion initiated$(NC)"; \
	else \
		echo "$(GREEN)Deletion cancelled$(NC)"; \
	fi