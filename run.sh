docker run -d \
    --name github-runner \
    -e RUNNER_URL="https://github.com/<org/user>/<repository>" \
    -e RUNNER_TOKEN="<TOKEN>" \
    -e RUNNER_NAME="docker-runner" \
    github-runner
