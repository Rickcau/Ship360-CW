# Ship360 Chat API - Deployment Considerations

This document outlines important considerations and best practices for deploying the Ship360 Chat API to Azure App Service.

## Azure App Service Configuration

### Recommended Tiers

| Environment | Recommended Tier | Rationale |
|-------------|------------------|-----------|
| Development | B1 | Cost-effective for development with adequate performance |
| Testing | B2 | More memory for integration testing and demonstrations |
| Production | P1v2 or P2v2 | Better performance, scaling, and SLA for production workloads |

### Scaling Configuration

- **Development**: Min instances = 1, Max instances = 1
- **Testing**: Min instances = 1, Max instances = 2
- **Production**: Min instances = 2, Max instances = 4+

Auto-scaling based on CPU usage is recommended for production environments.

## Environment Variables Management

### Security Best Practices

1. **Never commit sensitive values to source control**
   - Use `.env` files that are excluded via `.gitignore`
   - Consider using Azure Key Vault for production secrets

2. **Scope of variables**
   - `ship360-sample.env` - Template with placeholders (safe to commit)
   - `ship360-dev.env` - Development environment (don't commit)
   - `ship360-prod.env` - Production environment (don't commit)

3. **Sensitive variables**
   - `AZURE_OPENAI_API_KEY`
   - `SP360_TOKEN_PASSWORD`
   - Any other API keys or credentials

## Deployment Options

### App Service ZIP Deploy

The script uses Azure CLI's ZIP deployment method, which:

1. Creates a ZIP package of the application
2. Uploads it to Azure App Service
3. Deploys and extracts the package
4. Installs Python dependencies from requirements.txt
5. Starts the application

### Alternative Deployment Methods

- **GitHub Actions**: For CI/CD pipelines
- **Azure DevOps Pipelines**: For enterprise CI/CD workflows
- **Docker Containers**: For container-based deployment

## Performance Optimization

### Python Worker Configuration

The deployment script configures a gunicorn startup command:

```
python -m gunicorn app.main:app -w 1 -k uvicorn.workers.UvicornWorker --bind=0.0.0.0:$PORT --timeout=120
```

Recommendations:

- Development: 1 worker
- Production: Number of workers = (2 × CPU cores) + 1

### Startup Time Considerations

FastAPI applications with large dependencies can have slow cold starts:

- The first request after deployment may take 30+ seconds
- Consider using always-on setting in production
- Pre-compile Python bytecode during deployment
- Review and optimize imports

## Monitoring and Logging

### Azure Monitor Integration

Azure App Service automatically integrates with Azure Monitor:

1. Application logs appear in Log Stream
2. Metrics like CPU, memory, and request count are tracked
3. Alerts can be configured based on thresholds

### Custom Logging

The FastAPI application should:

1. Use structured logging with appropriate levels
2. Send logs to stdout/stderr (captured by App Service)
3. Include correlation IDs for tracing requests

## Cost Management

### Resource Optimization

- Use auto-scaling to balance cost and performance
- Consider daily/weekly start/stop schedules for non-production environments
- Implement Azure Advisor recommendations

### Estimated Costs (Monthly)

| Component | Development (B1) | Production (P1v2) |
|-----------|------------------|-------------------|
| App Service | ~$60 | ~$150 |
| Additional Services | Varies | Varies |

## Networking and Security

### IP Restrictions

Consider restricting access to the API:

```powershell
az webapp config access-restriction add --resource-group <group> --name <app> --rule-name "AllowMyIP" --action Allow --ip-address "<your-ip>/32" --priority 100
```

### Virtual Network Integration

For enhanced security in production:
- Deploy into a virtual network
- Use private endpoints for Azure OpenAI and other services
- Implement Azure Front Door for WAF protection

## Troubleshooting Guide

### Common Errors

1. **503 Service Unavailable**
   - Application may still be starting
   - Check application logs
   - Verify Python version compatibility

2. **500 Internal Server Error**
   - Check application logs
   - Verify environment variables
   - Test locally before deploying

3. **Deployment Timeout**
   - Large dependencies can cause timeouts
   - Check deployment status in Deployment Center
   - Consider optimizing requirements.txt

### Diagnostic Tools

- **Kudu Console**: Available at `https://<app-name>.scm.azurewebsites.net`
- **Log Stream**: Real-time application logs
- **Diagnose and Solve Problems**: Built-in troubleshooting tools

## Further Resources

- [FastAPI Deployment Documentation](https://fastapi.tiangolo.com/deployment/)
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Python on App Service](https://docs.microsoft.com/en-us/azure/app-service/configure-language-python)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)