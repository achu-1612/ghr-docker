docker run \
    -e RUNNER_URL="https://github.com/<org/user>/<repository>" \
    -e RUNNER_TOKEN="<TOKEN>" \
    -e RUNNER_NAME="docker-runner" \
    -e RUNNER_WORKDIR="/home/runner/actions-runner" \
    runner
