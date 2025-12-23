# LibreNMS Local Development Environment

This guide helps you set up a local development environment that matches GitHub CI, so you can validate your code **before** committing.

## Quick Start Options

### Option 1: VS Code Dev Container (Recommended for Windows/Mac)

The easiest way to get a fully configured environment:

1. **Prerequisites**: 
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - [VS Code](https://code.visualstudio.com/) with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

2. **Open in Container**:
   ```bash
   # Clone the repo
   git clone https://github.com/librenms/librenms.git
   cd librenms
   
   # Open in VS Code
   code .
   ```
   
   Then click "Reopen in Container" when prompted (or use Command Palette: `Dev Containers: Reopen in Container`)

3. **Run CI checks**:
   ```bash
   make test          # Full CI suite
   make quick-check   # Fast pre-commit check
   ```

### Option 2: Docker Compose (Manual Setup)

If you prefer not to use VS Code:

```bash
# Start the development stack
cd .devcontainer
docker compose up -d

# Enter the container
docker compose exec app bash

# Inside container - run setup
./devcontainer/post-create.sh

# Run CI checks
make test
```

### Option 3: Native Setup (Linux/WSL2)

If you have PHP 8.2+, Python 3, and MySQL locally:

```bash
# Install dependencies
composer install
npm install
pip3 install --user pylint python-memcached

# Set up test database
mysql -u root -e "CREATE DATABASE librenms_phpunit_78hunjuybybh"

# Configure .env
cp .env.example .env
# Edit .env with your database credentials

# Run migrations
php artisan migrate

# Run CI checks
./lnms dev:check
```

## Available Commands

### Makefile Commands (Recommended)

| Command | Description |
|---------|-------------|
| `make test` | Run **all** CI checks (same as GitHub Actions) |
| `make quick-check` | Fast syntax check (ideal for pre-commit) |
| `make lint` | Run linting only (PHP, Python, Bash) |
| `make style` | Fix code style with php-cs-fixer |
| `make unit` | Run PHPUnit tests |
| `make phpstan` | Run PHPStan static analysis |
| `make serve` | Start development web server |
| `make test-os OS=nokia-sros` | Test a specific OS |

### Direct lnms Commands

```bash
# Full CI check
./lnms dev:check --full --db

# Specific OS testing
./lnms dev:check --os nokia-sros --db

# Lint only
./lnms dev:check --lint-only

# Unit tests only
./lnms dev:check --unit-only --db

# Show all options
./lnms dev:check --help
```

## What Does CI Check?

The `make test` command runs the same checks as GitHub Actions:

1. **PHP Lint** (`parallel-lint`) - Syntax errors
2. **PHPStan** - Static analysis, type errors
3. **php-cs-fixer** - Code style (PSR-12)
4. **PHPUnit** - Unit tests and OS module tests
5. **Python lint** (`pylint`) - Python script linting
6. **Bash lint** - Shell script linting

## Testing Specific OS/Modules

```bash
# Test a specific OS (with SNMP simulator)
make test-os OS=nokia-sros

# Test multiple OSes
./lnms dev:check --os nokia-sros,juniper --db

# Test specific modules
./lnms dev:check --module bgp-peers,ports --db
```

## Git Pre-Commit Hook

The dev container automatically sets up a pre-commit hook. For manual setup:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Running lnms dev:check..."
php lnms dev:check
EOF
chmod +x .git/hooks/pre-commit
```

Now every commit will be validated before it's created.

## SNMP Simulator

For testing OS discovery and polling:

```bash
# Set up snmpsim (first time)
make snmpsim-setup

# Start snmpsim in background
make snmpsim-bg

# Or in foreground with debug output
make snmpsim
```

## Troubleshooting

### Database connection issues
```bash
# Verify database is running
docker compose ps

# Check connection
mysql -h db -u librenms -plibrenms librenms -e "SELECT 1"

# Re-run migrations
php artisan migrate:fresh
```

### Cache issues
```bash
make clean
# or
php artisan config:clear && php artisan cache:clear
```

### Composer issues
```bash
composer install --prefer-dist --no-cache
```

### Python/snmpsim issues
```bash
# Recreate the venv
rm -rf .python_venvs/snmpsim
php lnms dev:simulate --setup-venv
```

## IDE Setup

For best experience with VS Code:

```bash
make ide-helper
```

This generates:
- `_ide_helper.php` - Laravel facades
- `_ide_helper_models.php` - Eloquent models
- `.phpstorm.meta.php` - Container bindings

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   Dev Container                       │
│  ┌─────────────┐  ┌──────────┐  ┌─────────────────┐ │
│  │   PHP 8.4   │  │  Python  │  │    Node.js      │ │
│  │  Composer   │  │  pylint  │  │   npm/Vite      │ │
│  │  PHPUnit    │  │  snmpsim │  │                 │ │
│  └─────────────┘  └──────────┘  └─────────────────┘ │
│                        │                             │
│  ┌─────────────────────┴────────────────────────┐   │
│  │              Your Code (mounted)              │   │
│  │         /workspaces/librenms                  │   │
│  └───────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
           │                    │
           ▼                    ▼
    ┌────────────┐       ┌────────────┐
    │  MariaDB   │       │   Redis    │
    │   :3306    │       │   :6379    │
    └────────────┘       └────────────┘
```

## Contributing Workflow

1. **Create branch**: `git checkout -b feature/my-feature`
2. **Make changes**: Edit code
3. **Test locally**: `make test` (or `make quick-check` for speed)
4. **Commit**: Git pre-commit hook validates automatically
5. **Push & PR**: GitHub Actions will run the same checks

This ensures you catch errors locally before wasting time on CI failures!
