# Ship360 Infrastructure

This directory contains infrastructure and deployment-related code for the Ship360 project.

## Directory Structure

- **scripts/** - PowerShell and Bash scripts for deploying and managing the application
  - `test-deploy.ps1` - Script for testing deployments
  - `update-deployment.ps1` - Script for updating existing deployments

- **templates/** - Infrastructure as Code templates (ARM, Bicep, etc.)
  - *Currently empty, to be populated with IaC templates*

- **config/** - Environment configuration files
  - **dev/** - Development environment configuration
    - `env.sample` - Sample environment file for development
  - **prod/** - Production environment configuration
    - `env.sample` - Sample environment file for production

## Usage

### Deployment Scripts

- **Test Deployment**:
  ```powershell
  ./scripts/test-deploy.ps1 -EnvironmentName <env-name>
  ```

- **Update Deployment**:
  ```powershell
  ./scripts/update-deployment.ps1 -EnvironmentName <env-name>
  ```

### Environment Configuration

1. Copy the appropriate `env.sample` file from the config directory
2. Rename it to `.env` and fill in the required values
3. Use it with the deployment scripts

## Best Practices

- Do not commit actual `.env` files with sensitive information
- Only commit sample environment files with placeholder values
- Keep infrastructure code separate from application code
- Document all infrastructure changes and deployment procedures
