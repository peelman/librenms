-- Create test database with proper permissions (matching GitHub CI)
CREATE DATABASE IF NOT EXISTS librenms_phpunit_78hunjuybybh;
GRANT ALL PRIVILEGES ON librenms_phpunit_78hunjuybybh.* TO 'librenms'@'%';

-- Also grant on the main db
GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'%';

-- Set proper collation
ALTER DATABASE librenms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER DATABASE librenms_phpunit_78hunjuybybh CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

FLUSH PRIVILEGES;
