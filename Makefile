# Variables
AUTOMATION = python .build/automation.py

AUTOMATION_RUN = python .build/automation.py run

# Setup and installation
automation_setup:
	@$(AUTOMATION) setup

install: automation_setup

# Frontend targets
frontend-test:
	@$(AUTOMATION_RUN) frontend test

frontend-format:
	@$(AUTOMATION_RUN) frontend format

frontend-lint:
	@$(AUTOMATION_RUN) frontend lint

frontend-run:
	@$(AUTOMATION_RUN) frontend run

frontend-build:
	@$(AUTOMATION_RUN) frontend build

# Backend targets
backend-test:
	@$(AUTOMATION_RUN) backend test

backend-format:
	@$(AUTOMATION_RUN) backend format

backend-lint:
	@$(AUTOMATION_RUN) backend lint

backend-run:
	@$(AUTOMATION_RUN) backend run

backend-build:
	@$(AUTOMATION_RUN) backend build

# Terraform targets
init:
	@$(AUTOMATION_RUN) terraform init

init_templates:
	@$(AUTOMATION_RUN) terraform init_templates

fmt:
	@$(AUTOMATION_RUN) terraform fmt

tf_lint:
	@$(AUTOMATION_RUN) terraform lint

validate:
	@$(AUTOMATION_RUN) terraform validate

plan:
	@$(AUTOMATION_RUN) terraform plan

apply:
	@$(AUTOMATION_RUN) terraform apply

destroy:
	@$(AUTOMATION_RUN) terraform destroy

tf_security:
	@$(AUTOMATION_RUN) terraform security_check

tf_cost:
	@$(AUTOMATION_RUN) terraform cost_estimate

# Combined targets
frontend-refactor: frontend-format frontend-lint

backend-refactor: backend-format backend-lint

# Combined deploy target
deploy:
	@$(AUTOMATION_RUN) terraform apply

format-all: frontend-format backend-format

lint-all: frontend-lint backend-lint

# Build backend and frontend
build-all: frontend-build backend-build

# Test backend and frontend
test-all: frontend-test backend-test

# Deploy infrastructure
deploy-all: deploy

# Run backend and frontend
run-all: frontend-run backend-run

all: install lint-all test-all format-all deploy