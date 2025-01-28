# Remote Python Development

This repository provides a streamlined workflow for developing Python applications on low performance remote devices instead of using vscode server.
It includes automatic file synchronization, remote execution, and integrated debugging with VS Code.

## Why? 

VS Code's standard remote development extensions are too resource-intensive for ARM-based embedded devices. 

This template provides a alternative that:

- Uses simple SSH and rsync for file synchronization (~1MB footprint)
- Requires python on the remote device
- Minimal CPU and memory overhead (compared to vscode server)
- No additional server components needed
- Still provides full debugging capabilities
- Integrates seamlessly with VS Code


## Project Structure

```
.
├── .vscode/
│   ├── launch.json        # VS Code launch configurations
├── src/
│   ├── __init__.py
│   └── main.py           # Your main Python script
├── tools/
│   └── dev-sync.sh       # Development synchronization script
├── .gitignore
└── README.md
```


### Setup
1. Configuration

Create a `.dev-sync-config` file in _tools/_ directory with the following content:

```
SSH_KEY="/path/to/your/ssh/key" # Path to your SSH private key
SSH_HOST="remote-device-alias"  # SSH host alias for the remote device
HOST_IP="xxx.xxx.xxx.xxx"       # IP address of the remote device
USER="remote-user"              # Username for SSH connection
PORT="xxxx"                     # SSH port number
REMOTE_DIR="/path/on/remote"    # Directory on the remote device where code will be deployed
DEBUG_PORT="5678"               # Port for remote debugging (default: 5678)
```

2. VS Code Configuration

Create or update `.vscode/launch.json` in your project with the following configuration:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Remote Debug",
            "type": "python",
            "request": "attach",
            "connect": {
                "host": "xxx.xxx.xxx.xxx",  // remote device IP
                "port": 5678
            },
            "pathMappings": [
                {
                    "localRoot": "${workspaceFolder}",
                    "remoteRoot": "/path/on/remote"  // Should match REMOTE_DIR
                }
            ],
            "justMyCode": false,
            "redirectOutput": true
        }
    ]
}
```

### Usage

**Initial Setup**

```bash
./tools/dev-sync.sh setup
```

**Sync Code**

```bash
./tools/dev-sync.sh sync
```
**Run**

```bash
./tools/dev-sync.sh run src/main.py
```

**Debug**

Set breakpoints in VS Code

Start debug server:

```bash
./tools/dev-sync.sh debug run src/main.py
```

**In VS Code:**

- Open Run and Debug (Ctrl/Cmd + Shift + D)
- Select "Remote Debug"
- Press F5

**Stop Process**

```bash
./tools/dev-sync.sh stop
```