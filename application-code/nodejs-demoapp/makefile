# Used by `deploy` target, sets AWS deployment defaults, override as required
AWS_ACCOUNT_ID ?= 523443631803
AWS_REGION ?= us-west-2
AWS_AVAILABILITY_ZONES ?= $(AWS_REGION)a,$(AWS_REGION)b
AWS_STACK_NAME ?= nodejs-demoapp

# Used by `image`, `push` & `deploy` targets, override as required
IMAGE_REPO ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/nodejs-demoapp
IMAGE_TAG ?= latest$(if $(IMAGE_SUFFIX),-$(IMAGE_SUFFIX),)
IMAGE_TAG_FULL := $(IMAGE_REPO):$(IMAGE_TAG)

# Used by `multiarch-*` targets
PLATFORMS ?= linux/arm64,linux/amd64

# Used by `test-api` target
TEST_HOST ?= localhost:3000

# Don't change
SRC_DIR := src
REPO_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
CONTAINER_BASEDIR := /app

# Set this to false on initial stack creation
CREATE_SERVICE ?= true

.PHONY: help lint lint-fix image push run multiarch-image multiarch-push multiarch-manifest deploy undeploy clean test test-api test-report test-container .EXPORT_ALL_VARIABLES
.DEFAULT_GOAL := help

help: ## 💬 This help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: $(SRC_DIR)/node_modules ## 🔎 Lint & format, will not fix but sets exit code on error
	cd $(SRC_DIR); npm run lint

lint-fix: $(SRC_DIR)/node_modules ## 📜 Lint & format, will try to fix errors and modify code
	cd $(SRC_DIR); npm run lint-fix

image: ## 🔨 Build container image from Dockerfile
	docker build . --file build/Dockerfile \
	--tag $(IMAGE_TAG_FULL)

push: ## 📤 Push container image to registry
	docker push $(IMAGE_TAG_FULL)

multiarch-image: ## 🔨 Build multi-arch container image from Dockerfile
	docker buildx build . --file build/Dockerfile \
	--platform $(PLATFORMS) \
	--tag $(IMAGE_TAG_FULL)

multiarch-push: ## 📤 Build and push multi-arch container image to registry
	docker buildx build . --file build/Dockerfile \
	--platform $(PLATFORMS) \
	--tag $(IMAGE_TAG_FULL) \
	--push

multiarch-manifest: ## 📤 Build and push multi-arch manifest to registry
	docker manifest create $(IMAGE_TAG_FULL) \
		$(foreach suffix,$(IMAGE_SUFFIXES),$(IMAGE_TAG_FULL)-$(suffix))
	docker manifest push $(IMAGE_TAG_FULL)

run: $(SRC_DIR)/node_modules ## 🏃 Run locally using Node.js
	cd $(SRC_DIR); npm run watch

deploy: ## 🚀 Deploy to Amazon ECS
	aws cloudformation deploy \
		$(if $(CLOUDFORMATION_ROLE_ARN),--role-arn $(CLOUDFORMATION_ROLE_ARN),) \
		--capabilities CAPABILITY_IAM \
		--template-file $(REPO_DIR)/deploy/aws/ecs-service-template.yaml \
		--stack-name $(AWS_STACK_NAME) \
		--parameter-overrides \
			$(if $(ECS_CLUSTER),ClusterName=$(ECS_CLUSTER),) \
			$(if $(ECS_SERVICE),ServiceName=$(ECS_SERVICE),) \
			CreateService=$(CREATE_SERVICE) \
			AvailabilityZones=$(AWS_AVAILABILITY_ZONES) \
			CreateNATGateways=false \
			CreatePrivateSubnets=false \
			ImageTag=$(IMAGE_TAG)
	@echo "### 🚀 App deployed & available here: http://`aws cloudformation describe-stacks --stack-name $(AWS_STACK_NAME) --query 'Stacks[0].Outputs[?OutputKey==\`AlbDnsUrl\`].OutputValue' --output text`"

undeploy: ## 💀 Remove from AWS
	@echo "### WARNING! Going to delete $(AWS_STACK_NAME) 😲"
	aws cloudformation delete-stack --stack-name $(AWS_STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(AWS_STACK_NAME)

test: $(SRC_DIR)/node_modules ## 🎯 Unit tests with Mocha
	cd $(SRC_DIR); npm run test

test-report: $(SRC_DIR)/node_modules ## 🤡 Unit tests with Mocha & mochawesome report
	rm -rf $(SRC_DIR)/test-results.*
	cd $(SRC_DIR); npm run test-report

test-api: $(SRC_DIR)/node_modules .EXPORT_ALL_VARIABLES ## 🚦 Run integration API tests, server must be running
	cd $(SRC_DIR); npm run test-postman

test-container: .EXPORT_ALL_VARIABLES ## 🚦 Run integration API tests in container
	cd $(CONTAINER_BASEDIR) && npm install --production=false && npm start &
	until nc -z $${TEST_HOST%%:*} $${TEST_HOST##*:}; do sleep 1; done
	cd $(CONTAINER_BASEDIR) && npm run test-postman

clean: ## 🧹 Clean up project
	rm -rf $(SRC_DIR)/node_modules
	rm -rf $(SRC_DIR)/*.xml

# ============================================================================

$(SRC_DIR)/node_modules: $(SRC_DIR)/package.json
	cd $(SRC_DIR); npm install --silent
	touch -m $(SRC_DIR)/node_modules

$(SRC_DIR)/package.json:
	@echo "package.json was modified"
