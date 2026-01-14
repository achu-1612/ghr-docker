.PHONY: help build run restart redeploy stop clean logs remove deregister status profiles list create show delete

RUNNER_SCRIPT = ./runner.sh
SHELL := /bin/bash

help:
	@$(RUNNER_SCRIPT) help

build:
	@$(RUNNER_SCRIPT) build

run:
	@$(RUNNER_SCRIPT) run

restart:
	@$(RUNNER_SCRIPT) restart

redeploy:
	@$(RUNNER_SCRIPT) redeploy

stop:
	@$(RUNNER_SCRIPT) stop

logs:
	@$(RUNNER_SCRIPT) logs

status:
	@$(RUNNER_SCRIPT) status

deregister:
	@$(RUNNER_SCRIPT) deregister

remove:
	@$(RUNNER_SCRIPT) remove

profiles:
	@$(RUNNER_SCRIPT) profiles $(filter-out $@,$(MAKECMDGOALS))
