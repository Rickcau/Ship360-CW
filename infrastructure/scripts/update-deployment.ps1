# Quick update script - just the essentials
$tempDir = ".\temp-deploy"
if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force

Copy-Item -Path ".\app" -Destination "$tempDir\app" -Recurse -Force
Copy-Item -Path ".\requirements.txt" -Destination "$tempDir\requirements.txt" -Force
Copy-Item -Path ".\startup.py" -Destination "$tempDir\startup.py" -Force

Compress-Archive -Path "$tempDir\*" -DestinationPath ".\deploy.zip" -Force
Remove-Item -Path $tempDir -Recurse -Force

az webapp deployment source config-zip --name app-ship360-chat-dev2 --resource-group rg-ship360-dev2 --src ".\deploy.zip"
Remove-Item ".\deploy.zip" -Force