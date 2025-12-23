# LibreNMS Development Makefile
# Run `make help` for available commands

.PHONY: help test lint unit style serve snmpsim clean setup check quick-check

# Default target
help:
	@echo "LibreNMS Development Commands"
	@echo "=============================="
	@echo ""
	@echo "Testing (CI Parity):"
	@echo "  make test          Run all CI checks (lint + style + unit tests)"
	@echo "  make quick-check   Quick syntax check only (fast pre-commit)"
	@echo "  make lint          Run linting (PHP, Python, Bash)"
	@echo "  make style         Run and fix code style (php-cs-fixer)"
	@echo "  make unit          Run PHPUnit tests"
	@echo "  make phpstan       Run PHPStan static analysis"
	@echo ""
	@echo "Development:"
	@echo "  make serve         Start development web server"
	@echo "  make serve-bg      Start dev server in background"
	@echo "  make watch         Start Vite dev server (frontend HMR)"
	@echo "  make build         Build frontend assets"
	@echo ""
	@echo "SNMP Testing:"
	@echo "  make snmpsim       Start SNMP simulator"
	@echo "  make snmpsim-setup Set up SNMP simulator venv"
	@echo "  make test-os OS=nokia-sros  Test specific OS"
	@echo ""
	@echo "Utilities:"
	@echo "  make setup         Full development setup"
	@echo "  make clean         Clear caches"
	@echo "  make db-migrate    Run database migrations"
	@echo "  make db-fresh      Fresh database with seeding"
	@echo ""

# ============================================================================
# CI PARITY - Run the same checks as GitHub Actions
# ============================================================================

# Full CI check - matches what runs on GitHub
test:
	@echo "🔍 Running full CI checks (same as GitHub Actions)..."
	php lnms dev:check --full --db
	@echo "✅ All checks passed! Safe to commit."

# Quick pre-commit check (fast)
quick-check:
	@echo "⚡ Quick syntax check..."
	php lnms dev:check
	@echo "✅ Quick check passed!"

# Lint only
lint:
	@echo "🔍 Running lint checks..."
	php lnms dev:check --lint-only

# Style check and fix
style:
	@echo "🎨 Checking and fixing code style..."
	./vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.php -v
	@echo "✅ Style fixes applied"

# Style check without fixing (for CI)
style-check:
	@echo "🎨 Checking code style (no fixes)..."
	./vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.php --dry-run --diff

# PHPUnit tests
unit:
	@echo "🧪 Running PHPUnit tests..."
	php lnms dev:check --unit-only --db

# PHPStan static analysis
phpstan:
	@echo "🔬 Running PHPStan..."
	./vendor/bin/phpstan analyze --no-interaction --memory-limit=4G
	./vendor/bin/phpstan analyze --no-interaction --memory-limit=4G --configuration=phpstan-legacy.neon
	@echo "✅ PHPStan passed"

# Rector dry-run
rector:
	@echo "🔄 Running Rector (dry-run)..."
	./vendor/bin/rector process --dry-run --no-progress-bar --ansi --memory-limit=2G

# ============================================================================
# DEVELOPMENT
# ============================================================================

# Start development server
serve:
	@echo "🚀 Starting development server at http://localhost:8000"
	php lnms serve --host=0.0.0.0 --port=8000

# Start development server in background
serve-bg:
	@echo "🚀 Starting development server in background..."
	php lnms serve --host=0.0.0.0 --port=8000 &

# Vite dev server (frontend hot module replacement)
watch:
	@echo "👀 Starting Vite dev server..."
	npm run dev

# Build frontend assets
build:
	@echo "🏗️  Building frontend assets..."
	npm run build

# ============================================================================
# SNMP SIMULATOR
# ============================================================================

# Set up snmpsim virtualenv
snmpsim-setup:
	@echo "📦 Setting up SNMP simulator..."
	php lnms dev:simulate --setup-venv

# Start SNMP simulator
snmpsim:
	@echo "📡 Starting SNMP simulator..."
	.python_venvs/snmpsim/bin/snmpsim-command-responder-lite \
		--data-dir=tests/snmpsim \
		--agent-udpv4-endpoint=127.1.6.2:1162 \
		--log-level=debug

# Start snmpsim in background
snmpsim-bg:
	@echo "📡 Starting SNMP simulator in background..."
	.python_venvs/snmpsim/bin/snmpsim-command-responder-lite \
		--data-dir=tests/snmpsim \
		--agent-udpv4-endpoint=127.1.6.2:1162 \
		--log-level=error \
		--logging-method=file:/tmp/snmpsimd.log &
	@echo "SNMP simulator running, logs at /tmp/snmpsimd.log"

# Test specific OS (usage: make test-os OS=nokia-sros)
test-os:
ifndef OS
	@echo "Usage: make test-os OS=<os-name>"
	@echo "Examples:"
	@echo "  make test-os OS=nokia-sros"
	@echo "  make test-os OS=linux"
	@echo "  make test-os OS=cisco"
else
	@echo "🧪 Testing OS: $(OS)"
	php lnms dev:check --os $(OS) --db
endif

# ============================================================================
# DATABASE
# ============================================================================

# Run migrations
db-migrate:
	@echo "🗄️  Running migrations..."
	php artisan migrate

# Fresh database with seeds
db-fresh:
	@echo "🗄️  Fresh database with seeding..."
	php artisan migrate:fresh --seed

# ============================================================================
# SETUP & UTILITIES
# ============================================================================

# Full development setup
setup:
	@echo "🚀 Full development setup..."
	composer install --prefer-dist
	npm install
	pip3 install --user pylint python-memcached mysqlclient
	php lnms dev:simulate --setup-venv || true
	touch database/testing.sqlite
	php artisan migrate
	npm run build
	@echo "✅ Setup complete!"

# Clear all caches
clean:
	@echo "🧹 Clearing caches..."
	php artisan config:clear
	php artisan cache:clear
	php artisan route:clear
	php artisan view:clear
	@echo "✅ Caches cleared"

# IDE helper files
ide-helper:
	@echo "📝 Generating IDE helper files..."
	php artisan ide-helper:generate
	php artisan ide-helper:models --nowrite
	php artisan ide-helper:meta
	@echo "✅ IDE helpers generated"
