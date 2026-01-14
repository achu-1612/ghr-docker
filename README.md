# GitHub Actions Self-Hosted Runner in Docker

Profile-based Docker setup for managing GitHub Actions self-hosted runners. Supports both repository and organization-level runners with automated token management via GitHub CLI.

## Prerequisites

- Docker
- GitHub CLI (`gh`) authenticated: `gh auth login`
- Bash shell
- jq

## Quick Start

```bash
# Create a profile
make profiles create

# Deploy runners
make run

# Check status
make status
```

## Commands

```bash
make build           # Build Docker image
make run             # Deploy runners (interactive)
make restart         # Restart containers
make redeploy        # Remove + rebuild + deploy
make stop            # Stop all runners
make logs            # View logs
make status          # Show status
make deregister      # Deregister from GitHub
make remove          # Full cleanup (deregister + remove)

make profiles create
make profiles list
make profiles show
make profiles delete
```

## Options

Pass options after the command (e.g., `make run --profile myproject`)

```bash
--profile <name>     # Use saved profile
--owner <name>       # GitHub username or org
--repo <name>        # Repository (omit for org-level)
--prefix <name>      # Runner name prefix
--count <number>     # Number of runners
```

## Examples

```bash
# Repository-level runners
make run --owner username --repo my-repo --count 3

# Organization-level runners  
make run --owner myorg --count 2

# Using profiles
make run --profile myproject
make redeploy --profile myproject
make remove --profile myproject
```

## Profile Configuration

Profiles are stored in `.profiles.json`:

```json
{
  "profile-name": {
    "OWNER": "github-username-or-org",
    "REPO": "repository-name",
    "RUNNER_NAME_PREFIX": "docker-runner",
    "RUNNER_COUNT": 1
  }
}
```

## Troubleshooting

**Authentication error**: Check `gh auth status` and ensure admin access

**View logs**: `make logs` or `docker logs <container-name>`

**Cleanup offline runners**: `make deregister --profile <name>`

## License

[MIT License](LICENSE)

