# Azure App Service Deployment Considerations

## Problem Analysis

When deploying a FastAPI application to Azure App Service on Linux, you may encounter `ModuleNotFoundError: No module named 'uvicorn'` even though the packages are correctly installed in the virtual environment. This happens because the startup command isn't properly activating the virtual environment.

### Key Observations
- Virtual environment exists at `/home/site/wwwroot/venv/`
- Packages (including uvicorn) are installed in `venv/lib/site-packages/`
- Azure App Service on Linux uses containerization even for "code" deployments
- Default Python path may not include the virtual environment

## Solution Options

### Option 1: Activate Virtual Environment in Startup Command (Recommended)

Modify the startup command to activate the virtual environment first:

```powershell
# In Set-StartupCommand function
$startupCommand = "source /home/site/wwwroot/venv/bin/activate && gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind=0.0.0.0:8000 --timeout 600"
```

**Pros:** Most explicit and reliable approach
**Cons:** Slightly longer startup command

### Option 2: Use Virtual Environment Python Directly

Use the virtual environment's Python interpreter directly:

```powershell
$startupCommand = "/home/site/wwwroot/venv/bin/python -m gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind=0.0.0.0:8000 --timeout 600"
```

**Pros:** Direct path to correct Python
**Cons:** Hardcoded path assumptions

### Option 3: Set PYTHONPATH Environment Variable

Add PYTHONPATH to your app settings:

```powershell
# In Set-EnvironmentVariables function, add to $appSettings array:
$appSettings += "PYTHONPATH=/home/site/wwwroot/venv/lib/python3.11/site-packages"
```

**Pros:** Clean separation of concerns
**Cons:** Version-specific path (python3.11)

### Option 4: Use Default Python Path

Let Azure handle the virtual environment automatically:

```powershell
$startupCommand = "python -m gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind=0.0.0.0:8000 --timeout 600"
```

**Pros:** Simplest approach
**Cons:** May not work if Azure doesn't auto-activate venv

## Additional Required Fixes

### 1. Port Specification
Ensure your startup command specifies port 8000:

```powershell
# Wrong (missing port)
--bind=0.0.0.0

# Correct
--bind=0.0.0.0:8000
```

### 2. Remove web.config for Linux
The PowerShell script creates a `web.config` file, but this is only for Windows App Service. Remove this section:

```powershell
# Remove this entire block from Deploy-Application function
$webConfigPath = Join-Path $tempDir "web.config"
$webConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<!-- ... remove entire web.config creation -->
```

### 3. Add Dependency Validation
Enhance the prerequisites check:

```powershell
# Add to Test-Prerequisites function
$requirementsContent = Get-Content $requirementsPath
if (-not ($requirementsContent -match "uvicorn")) {
    Write-ColorOutput "⚠ Warning: uvicorn not found in requirements.txt" "Yellow"
    Write-ColorOutput "  This is required for the gunicorn uvicorn worker" "Yellow"
}
if (-not ($requirementsContent -match "gunicorn")) {
    Write-ColorOutput "⚠ Warning: gunicorn not found in requirements.txt" "Yellow"
}
```

## Debugging Commands

For troubleshooting, you can temporarily use a debug startup command:

```powershell
# Debug version to see what's happening
$startupCommand = "echo 'Python location:' && which python && echo 'Python version:' && python --version && echo 'Installed packages:' && pip list | grep -E '(uvicorn|gunicorn|fastapi)' && echo 'Starting app...' && source /home/site/wwwroot/venv/bin/activate && gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind=0.0.0.0:8000 --timeout 600"
```

## Alternative Startup Commands

### Simple Uvicorn (for development/testing)
```powershell
$startupCommand = "source /home/site/wwwroot/venv/bin/activate && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"
```

### Gunicorn with sync workers (if no async needed)
```powershell
$startupCommand = "source /home/site/wwwroot/venv/bin/activate && gunicorn -w 4 -b 0.0.0.0:8000 app.main:app --timeout 600"
```

## Implementation Steps

1. **Update the startup command** in your PowerShell script using Option 1
2. **Remove the web.config creation** section
3. **Test the deployment** and check logs
4. **If issues persist**, try the debug command to see what's happening
5. **Once working**, switch back to the production startup command

## Expected Results

After implementing these fixes:
- Virtual environment will be properly activated
- Python packages will be found
- Application will start successfully on port 8000
- Health checks should pass

## Verification

Check these items after deployment:
1. Application responds at `https://your-app.azurewebsites.net/`
2. API documentation available at `https://your-app.azurewebsites.net/docs`
3. No `ModuleNotFoundError` in the container logs
4. Warmup requests succeed without timeout
