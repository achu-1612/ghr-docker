#!/bin/bash
set -e

# Verify required environment variables
if [ -z "$RUNNER_URL" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "ERROR: Required environment variables RUNNER_URL and RUNNER_TOKEN must be set"
    exit 1
fi

# Function to handle cleanup
cleanup() {
    echo "Cleaning up the runner..."
    if [ -f "./config.sh" ]; then
        if ! ./config.sh remove --token "$RUNNER_TOKEN"; then
            echo "WARNING: Failed to remove runner. It might have already been removed."
        fi
    fi
    exit 0
}

# Trap signals for graceful shutdown
trap cleanup SIGTERM SIGINT SIGQUIT

# Configuring the GitHub Actions Runner
if [ ! -f .runner ]; then
    echo "Configuring the runner..."
    if ! ./config.sh --url "$RUNNER_URL" --token "$RUNNER_TOKEN" \
        --name "${RUNNER_NAME:-$(hostname)}" --work "${RUNNER_WORKDIR}" \
        --unattended --replace; then
        echo "ERROR: Failed to configure the runner"
        exit 1
    fi
fi

# Run the runner
echo "Starting the runner for $RUNNER_URL"

# Start the runner in background
./run.sh &
RUNNER_PID=$!

# Wait for the runner to finish (while handling signals)
wait $RUNNER_PID || true
