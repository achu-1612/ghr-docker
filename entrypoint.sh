#!/bin/bash
set -e

# Configuring the GitHub Actions Runner
if [ ! -f .runner ]; then
    echo "Configuring the runner..."
    # ./config.sh --url "$RUNNER_URL" --token "$RUNNER_TOKEN" --name "${RUNNER_NAME:-$(hostname)}" --work "${RUNNER_WORKDIR}" --unattended --replace
fi

# Run the runner
echo "Starting the runner for $RUNNER_URL"

exec ./run.sh
