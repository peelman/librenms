#!/bin/bash
set -e

echo "🚀 Setting up LibreNMS development environment..."

cd /workspaces/librenms

# Install PHP dependencies
echo "📦 Installing Composer dependencies..."
composer install --prefer-dist --no-interaction

# Install Python dependencies (for snmpsim and linting)
echo "🐍 Installing Python dependencies..."
pip3 install --user pylint python-memcached mysqlclient

# Set up snmpsim virtual environment (matches CI workflow)
echo "🔧 Setting up SNMP simulator..."
php lnms dev:simulate --setup-venv || true

# Install Node dependencies
echo "📦 Installing npm dependencies..."
npm install

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    echo "⚙️  Creating .env file..."
    cat > .env << 'EOF'
APP_ENV=local
APP_DEBUG=true
APP_KEY=base64:vHI+YHgkyCDad31iPEErGSNEOWO21wNzV+zyENKQv04=
APP_URL=http://localhost:8000

DB_HOST=db
DB_PORT=3306
DB_DATABASE=librenms
DB_USERNAME=librenms
DB_PASSWORD=librenms

DB_TEST_DRIVER=mysql
DB_TEST_HOST=db
DB_TEST_PORT=3306
DB_TEST_DATABASE=librenms_phpunit_78hunjuybybh
DB_TEST_USERNAME=librenms
DB_TEST_PASSWORD=librenms

REDIS_HOST=redis
REDIS_PORT=6379

CACHE_DRIVER=redis
SESSION_DRIVER=redis

LOG_CHANNEL=single
EOF
fi

# Create SQLite test database
echo "📊 Setting up SQLite for testing..."
touch database/testing.sqlite

# Run migrations
echo "🗄️  Running database migrations..."
php artisan migrate --force || true

# Copy test config if needed
if [ -f tests/testing_config.yaml ]; then
    echo "📋 Copying test configuration..."
    cp tests/testing_config.yaml database/seeders/config/ 2>/dev/null || true
fi

# Build frontend assets
echo "🎨 Building frontend assets..."
npm run build || true

# Set up git hooks for pre-commit validation
if [ -d .git ]; then
    echo "🔗 Setting up git pre-commit hook..."
    cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash
echo "Running lnms dev:check..."
php lnms dev:check
HOOK
    chmod +x .git/hooks/pre-commit
fi

echo ""
echo "✅ Development environment ready!"
echo ""
echo "📝 Quick commands:"
echo "   make test          - Run all CI checks locally"
echo "   make lint          - Run linting only"
echo "   make unit          - Run PHPUnit tests"
echo "   make serve         - Start development server"
echo "   make style         - Fix code style"
echo ""
echo "   Or use: php lnms dev:check [options]"
echo ""
