# Setup —————————————————————————————————————————————————————————————————————————
DOCKER_COMPOSE = docker-compose
EXEC_PHP = $(DOCKER_COMPOSE) exec -T $(OPT_EXEC_USER) php
EXEC_YARN  = yarn
SYMFONY    = $(EXEC_PHP) bin/console
COMPOSER   = $(EXEC_PHP) composer
VENDOR_BIN = $(EXEC_PHP) ./vendor/bin/
NPX        = npx
NPM        = npm

.DEFAULT_GOAL := help
Arguments := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))


## —— My Make file  —————————————————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## —— Docker  —————————————————————————————————————————————
build: ## Build
	$(DOCKER_COMPOSE) pull --ignore-pull-failures
	$(DOCKER_COMPOSE) build --pull

kill: ## Kill all docker
	$(DOCKER_COMPOSE) kill
	docker rm $$(docker ps -a -q) && echo "" > /dev/null 2>&1 || echo "" > /dev/null 2>&1
	@rm -rf vendor > /dev/null 2>&1 && echo "" > /dev/null 2>&1 || echo "" > /dev/null 2>&1
	@rm -rf var/cache > /dev/null 2>&1 && echo "" > /dev/null 2>&1  || echo "" > /dev/null 2>&1
	sudo rm -rf /mnt/datatobuild/db > /dev/null 2>&1 && echo "" > /dev/null 2>&1  || echo "" > /dev/null 2>&1
	sudo mkdir /mnt/datatobuild/db > /dev/null 2>&1 && echo "" > /dev/null 2>&1  || echo "" > /dev/null 2>&1

up: ## Start all docker container
	$(DOCKER_COMPOSE) up -d

down: ## Stop, delete all docker containers
	$(DOCKER_COMPOSE) down --volumes --remove-orphans

stop: ## Stop all docker containers
	$(DOCKER_COMPOSE) stop

## —— Composer —————————————————————————————————————————————————————————————————
install: composer.lock ## Install vendors according to the current composer.lock file
	$(COMPOSER) install --no-interaction --no-progress --prefer-dist

update: composer.json ## Update vendors according to the current composer.json file
	$(COMPOSER) update --no-interaction --no-progress --prefer-dist
## —— Symfony ——————————————————————————————————————————————————————————————————
sf: ## List Symfony command
	$(SYMFONY) $(Arguments)

cc: ## Clear cache
	$(SYMFONY) c:c

warmup: ## Warmump the cache
	$(SYMFONY) cache:warmup

fix-perms: ## Fix permissions of all var files
	chmod -R 777 var/*

purge: ## Purge cache and logs
	rm -rf var/cache/* var/logs/*

diff: vendor  ## doctrine migration diff
	$(SYMFONY) d:m:diff

dmm: vendor  ## Doctrine migration migrate
	$(SYMFONY) d:m:m

cdb-dr: vendor  ## Clean db to delete bimeo users test dry run
	$(SYMFONY) app:db:cleaner --dry-run

cdb: vendor  ## Clean db to delete bimeo users test
	$(SYMFONY) app:db:cleaner

imp-db: scripts ## Import prod db
	sh ./scripts/db/dump.sh

## —— Project ———————————————————————————————————————————————————————————————————
new: kill build up initfile update imp-db ## First installation of the project

initfile: .env ## Manage .env file
	cp phpcs.xml.dist .phpcs.xml
	cp commit-msg.dist .git/hooks/commit-msg
	cp pre-commit.dist .git/hooks/pre-commit
	chmod ug+x .git/hooks/commit-msg
	chmod ug+x .git/hooks/pre-commit

## —— Assets ————————————————————————————————————————————————————————————————————
watch: assets ## Turn on watch mode for assets
	$(EXEC_YARN) watch

dev: assets ## Build for dev environment
	$(EXEC_YARN) dev

prod: assets ## Build for prod environment
	$(EXEC_YARN) prod

ni: assets ## Yarn Install Force
	rm -rf node_modules
	rm -rf package-lock.json
	$(NPM) install --force

## —— Coding standards ✨ ——————————————————————————————————————————————————————
lint-css: .stylelint.json ## Lint CSS using coding standards
	$(NPX) stylelint --config ./.stylelint.json "**/*.css" --allow-empty-input

lint-js: .eslintrc.json ## Lints JS using coding standards
	$(NPX) eslint assets/js

fix-js: .eslintrc.json ## Fixes JS files
	$(NPX) eslint assets/js --fix

phpcs: vendor .phpcs.xml ## PHP_CodeSnifer (https://github.com/squizlabs/PHP_CodeSniffer)
	$(VENDOR_BIN)phpcs -v --standard=.phpcs.xml src --ignore=Migrations/*

phpcbf: vendor .phpcs.xml ## PHP_CodeSnifer (https://github.com/squizlabs/PHP_CodeSniffer)
	$(VENDOR_BIN)phpcbf -v --standard=.phpcs.xml src

lint-twig: ## Lint twig files
	$(SYMFONY) lint:twig

lint: phpcs lint-js

stan: .phpstan.neon## Run PHPStan (https://github.com/phpstan/phpstan/tree/1.4.x)
	$(VENDOR_BIN)phpstan analyse -c .phpstan.neon --memory-limit 1G
