FROM ubuntu:22.04

# Set environment variables
ENV RUNNER_VERSION=2.321.0
ENV RUNNER_WORKDIR=/home/runner/actions-runner
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_WORKDIR=/home/runner/actions-runner

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl tar git jq make \
    && rm -rf /var/lib/apt/lists/*

# Create directory for the runner
RUN mkdir -p $RUNNER_WORKDIR
WORKDIR $RUNNER_WORKDIR

# Download and install the GitHub Actions runner
RUN curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf actions-runner.tar.gz \
    && rm -f actions-runner.tar.gz

    # Install dependencies and runner dependencies
RUN ./bin/installdependencies.sh

# Create a non-root user
RUN useradd -m runner && mkdir -p $RUNNER_WORKDIR && chown -R runner:runner /home/runner

# Switch to the non-root user
USER runner
WORKDIR $RUNNER_WORKDIR

# Add the entrypoint script
COPY --chown=runner:runner entrypoint.sh .

# Set execute permissions
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
