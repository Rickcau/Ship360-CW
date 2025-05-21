# Ship360
GenAI for Ship360

![image](https://github.com/user-attachments/assets/ef7b803b-672c-452c-a2da-634c4bc803e0)


## Branch Protection Rules

Restrict deletions:

✔️ No one can delete the main branch.
Require a pull request before merging (1 approval):

✔️ All changes must go through a PR and be approved by at least one reviewer.
Dismiss stale pull request approvals when new commits are pushed:

✔️ If new commits are added to a PR, previous approvals are dismissed, ensuring reviewers see the latest changes.
 Allowed merge methods: Merge, Squash, Rebase:

✔️ You allow all standard merge methods. This is fine—choose what fits your workflow.
Require status checks to pass:

✔️ PRs can only be merged if all required status checks pass.
⚠️ Note: You haven’t added any specific status checks yet, so this won’t block merges until you do.

Require branches to be up to date before merging:
✔️ PRs must be up to date with main before merging, preventing integration issues.

Blocked force pushes:
✔️ No one can force-push to main, protecting history.

## Deploying to Azure
You can run the `deploy-to-azure-v2.ps1` script from a PowerShell Terminal Window in VS Code to setup the API in Azure.  When deploying a Python solution to Azure it can take 20 to 60 minutes to get everything setup.

### Use Log Stream to see the process in Azure 
Navigate to the Kudu site the URL will be something like this `https://ship360-chat-api-<some number>.scm.azurewebsites.net`, then click on the Log Stream link in the UI.

The **Log Stream** is streaming the status of the install / setup in real-time.  For example, when I captured my setup it was running the PIP install.

   ~~~
        2025-05-20T11:37:53  Welcome, you are now connected to log-streaming service.
        Starting Log Tail -n 10 of existing logs ----
        /appsvctmp/volatile/logs/runtime/container.log 
        2025-05-20T11:37:45.2472847Z 
        2025-05-20T11:37:45.3075393Z Source directory     : /tmp/8dd9792abf1bc3e
        2025-05-20T11:37:45.3475901Z Destination directory: /home/site/wwwroot
        2025-05-20T11:37:45.3979078Z 
        2025-05-20T11:37:45.4278243Z 
        2025-05-20T11:37:45.4878547Z Downloading and extracting 'python' version '3.12.10' to '/tmp/oryx/platforms/python/3.12.10'...
        2025-05-20T11:37:45.5290663Z Detected image debian flavor: bullseye.
        2025-05-20T11:37:49.8010399Z Downloaded in 4 sec(s).
        2025-05-20T11:37:49.8410017Z Verifying checksum...
        2025-05-20T11:37:49.9709681Z Extracting contents...
        Ending Log Tail of existing logs ---
        Starting Live Log Stream ---
        2025-05-20T11:38:09.7953437Z ...............
        2025-05-20T11:38:09.7964119Z performing sha512 checksum for: python...
        2025-05-20T11:38:11.9246816Z Done in 26 sec(s).
        2025-05-20T11:38:12.0059908Z 
        2025-05-20T11:38:12.0456177Z image detector file exists, platform is python..
        2025-05-20T11:38:12.1066282Z OS detector file exists, OS is bullseye..
        2025-05-20T11:38:12.4252994Z Python Version: /tmp/oryx/platforms/python/3.12.10/bin/python3.12
        2025-05-20T11:38:12.5055320Z Creating directory for command manifest file if it does not exist
        2025-05-20T11:38:12.5582352Z Removing existing manifest file
        2025-05-20T11:38:12.6564228Z Python Virtual Environment: antenv
        2025-05-20T11:38:12.8288053Z Creating virtual environment...
        2025-05-20T11:38:28.1587436Z ...........
        2025-05-20T11:38:28.1764249Z Activating virtual environment...
        2025-05-20T11:38:28.2684945Z Running pip install
   ~~~
