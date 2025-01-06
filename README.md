# GitHub Actions Self-Hosted Runner in Docker

This repository provides a Dockerized setup for running a GitHub Actions self-hosted runner. It creates an isolated and lightweight environment, enabling you to run workflows efficiently on your own infrastructure.

## Features
- Runs as a non-root user for enhanced security.
- Automatically installs and configures the GitHub Actions runner.
- Supports easy deployment using Docker.

## Prerequisites
- Docker installed on your machine.
- A GitHub Runner Token for registration.

## Usage

### 1. Build the Docker Image

Clone this repository and navigate to the directory:

```bash
git clone https://github.com/achu-1612/ghr-docker
cd ghr-docker
```

Build the Docker image:

```bash
docker build -t github-runner .
```

### 2. Run the Container

Run the container with the required environment variables:

```bash
docker run -d \
    --name self-hosted-runner \
    -e RUNNER_URL="https://github.com/<your-org-or-user>/<repository-name>" \
    -e RUNNER_TOKEN="<self-hosted-runner-token>" \
    -e RUNNER_NAME="docker-runner" \
    github-runner
```

Replace the placeholders:
- `<your-org-or-user>/<repository-name>`: Repository details
- `<self-hosted-runner-token>`: Runner registration token `[Repository Settings -> Actions -> Runners -> New self-hosted runner]`

### 3. Verify the Runner

Go to your GitHub repository or organization settings:

- Navigate to **Settings** → **Actions** → **Runners**.
- You should see the runner listed as `docker-runner` and ready for use.

## Stopping and Removing the Runner

To stop the container:

```bash
docker stop self-hosted-runner
```

To remove the container:

```bash
docker rm self-hosted-runner
```

## Customization

### Environment Variables

| Variable          | Description                                                |
|-------------------|------------------------------------------------------------|
| `RUNNER_URL`      | GitHub repository, user, or organization URL.              |
| `RUNNER_TOKEN`    | Personal Access Token for authenticating the runner.       |
| `RUNNER_NAME`     | (Optional) Name for the runner. Defaults to hostname.      |
| `RUNNER_WORKDIR`  | (Optional) Working directory for the runner.               |

### Updating Runner Version

To update the GitHub Actions runner version, edit the `RUNNER_VERSION` in the `Dockerfile`:

```dockerfile
ENV RUNNER_VERSION=2.321.0
```

Rebuild the Docker image:

```bash
docker build -t github-runner .
```

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

## License

This project is licensed under the [MIT License](LICENSE).

---

If you have questions or run into issues, please open an issue in this repository.

