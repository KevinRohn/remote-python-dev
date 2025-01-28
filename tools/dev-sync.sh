#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Config files
CONFIG_FILE="$SCRIPT_DIR/.dev-sync-config"
SYNC_CONFIG="$SCRIPT_DIR/.syncconfig"

# Process management
PID_FILE="$SCRIPT_DIR/.python_pid"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please create a .dev-sync-config file with the following variables:"
    echo "SSH_KEY=\"path/to/your/ssh/key\""
    echo "SSH_HOST=\"your-host-alias\""
    echo "HOST_IP=\"your-host-ip\""
    echo "USER=\"remote-user\""
    echo "PORT=\"ssh-port\""
    echo "REMOTE_DIR=\"/path/to/remote/directory\""
    echo "DEBUG_PORT=\"debug-port\""
    exit 1
fi

# Verify required variables are set
REQUIRED_VARS=("SSH_KEY" "SSH_HOST" "HOST_IP" "USER" "PORT" "REMOTE_DIR" "DEBUG_PORT")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in $CONFIG_FILE"
        exit 1
    fi
done

# Cleanup function
cleanup() {
    if [ -f "$PID_FILE" ]; then
        REMOTE_PID=$(cat "$PID_FILE")
        if [ ! -z "$REMOTE_PID" ]; then
            echo "Cleaning up remote process..."
            $SSH_CMD "$SSH_HOST" "kill -15 $REMOTE_PID 2>/dev/null || kill -9 $REMOTE_PID 2>/dev/null" || true
        fi
        rm "$PID_FILE"
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Help function
show_help() {
    echo "Usage: $0 [options] {setup|sync|run|debug|stop} <python_file>"
    echo
    echo "Commands:"
    echo "  setup                 Initial setup of remote environment"
    echo "  sync                  Sync local files to remote"
    echo "  run <file>           Run a Python file on remote"
    echo "  debug <file>         Run a Python file with debugging enabled"
    echo "  stop                 Stop running Python process"
    echo
    echo "Configuration:"
    echo "  Create a .dev-sync-config file in the same directory as this script with:"
    echo "    SSH_KEY=\"path/to/your/ssh/key\""
    echo "    SSH_HOST=\"your-host-alias\""
    echo "    HOST_IP=\"your-host-ip\""
    echo "    USER=\"remote-user\""
    echo "    PORT=\"ssh-port\""
    echo "    REMOTE_DIR=\"/path/to/remote/directory\""
    echo "    DEBUG_PORT=\"debug-port\""
}

# Project Configuration
LOCAL_DIR="$PROJECT_ROOT"
SSH_CONFIG="$HOME/.ssh/config"

# SSH commands with key configuration
SSH_CMD="ssh -i $SSH_KEY"
SCP_CMD="scp -i $SSH_KEY"
RSYNC_CMD="rsync -e \"ssh -i $SSH_KEY\""

# Function to setup or update SSH config
setup_ssh() {
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Remove existing host entry if it exists
    if grep -q "Host $SSH_HOST" "$SSH_CONFIG" 2>/dev/null; then
        sed "/Host $SSH_HOST/,/StrictHostKeyChecking.*/d" "$SSH_CONFIG" > "$SSH_CONFIG.tmp"
        mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"
    fi

    # Add new host entry
    cat >> "$SSH_CONFIG" << EOL

Host $SSH_HOST
    HostName $HOST_IP
    User $USER
    IdentityFile $SSH_KEY
    Port $PORT
    StrictHostKeyChecking accept-new
EOL
    chmod 600 "$SSH_CONFIG"
    echo "SSH config updated for host $SSH_HOST ($HOST_IP)"
}

# Function to sync changes
sync_changes() {
    if [ ! -f "$SYNC_CONFIG" ]; then
        echo "Error: Sync configuration file not found at $SYNC_CONFIG"
        exit 1
    fi

    echo "Syncing from: $LOCAL_DIR to $SSH_HOST:$REMOTE_DIR"
    eval $RSYNC_CMD -avz --delete \
        --include-from="$SYNC_CONFIG" \
        "$LOCAL_DIR/" \
        "$SSH_HOST:$REMOTE_DIR/"
}

# Function to setup remote debugging
setup_debug() {
    echo "Setting up remote debugging environment..."
    $SSH_CMD "$SSH_HOST" "python3 -m pip install debugpy"
}

# Function to execute commands remotely
remote_exec() {
    echo "Running: python3 $1 on remote device ($SSH_HOST)..."
    
    # Kill any existing Python processes
    $SSH_CMD "$SSH_HOST" "pkill -f 'python3 $1'" || true
    
    # Start the new process
    $SSH_CMD "$SSH_HOST" "cd ${REMOTE_DIR} && python3 $1"
}

# Function to execute commands remotely with debugging
remote_exec_debug() {
    echo "Starting debugpy for: python3 $1 on device ($SSH_HOST)..."
    
    # Kill any existing debugpy processes
    $SSH_CMD "$SSH_HOST" "pkill -f 'debugpy'" || true
    
    # Start debugpy in listen mode
    DEBUGPY_CMD="python3 -m debugpy --listen 0.0.0.0:${DEBUG_PORT} --wait-for-client $1"
    $SSH_CMD "$SSH_HOST" "cd ${REMOTE_DIR} && $DEBUGPY_CMD"
}

# Setup development environment
setup_dev() {
    setup_ssh
    $SSH_CMD "$SSH_HOST" "mkdir -p ${REMOTE_DIR}"
    sync_changes
    setup_debug
    echo "Development environment setup complete for $SSH_HOST ($HOST_IP)!"
}

# Main command processing
case "$1" in
    "setup")
        setup_dev
        ;;
    "sync")
        sync_changes
        ;;
    "run")
        if [ -z "$2" ]; then
            echo "Error: Please specify a Python file to run"
            echo "Usage: $0 run <python_file>"
            echo "Example: $0 run src/main.py"
            exit 1
        fi
        sync_changes
        remote_exec "$2"
        ;;
    "debug")
        if [ -z "$2" ]; then
            echo "Error: Please specify a Python file to debug"
            echo "Usage: $0 debug <python_file>"
            echo "Example: $0 debug src/main.py"
            exit 1
        fi
        sync_changes
        echo "Starting debug session. Make sure to:"
        echo "1. Set your breakpoints in VS Code"
        echo "2. Use the 'Remote Debug' configuration"
        echo "3. Connect to ${HOST_IP}:${DEBUG_PORT}"
        remote_exec_debug "$2"
        ;;
    "stop")
        if [ -f "$PID_FILE" ]; then
            cleanup
            echo "Stopped running processes"
        else
            echo "No running process found"
        fi
        ;;
    *)
        show_help
        exit 1
        ;;
esac