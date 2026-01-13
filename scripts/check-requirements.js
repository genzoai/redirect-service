#!/usr/bin/env node

/**
 * Universal Redirect Service - System Requirements Checker
 * Validates that the system meets all prerequisites for installation
 */

const { execSync } = require('child_process');
const fs = require('fs');
const net = require('net');

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  bold: '\x1b[1m'
};

// Requirements
// Updated 2026-01-13 to reflect current LTS versions
const REQUIREMENTS = {
  node: { min: '24.0.0', command: 'node --version' },      // Node.js 24 LTS (Krypton) - support until Apr 2028
  npm: { min: '11.0.0', command: 'npm --version' },        // npm 11 comes with Node.js 24
  mysql: { min: '8.4.0', command: 'mysql --version', optional: false },  // MySQL 8.4 LTS - support until 2032
  nginx: { min: '1.26.0', command: 'nginx -v 2>&1', optional: true },    // Nginx stable baseline
  certbot: { min: '5.0.0', command: 'certbot --version', optional: true } // Certbot 5.x modern baseline
};

const DEFAULT_PORT = 3077;

class RequirementsChecker {
  constructor() {
    this.results = [];
    this.errors = 0;
    this.warnings = 0;
  }

  /**
   * Main check function
   */
  async check() {
    console.log(`${colors.bold}${colors.blue}Universal Redirect Service - Requirements Check${colors.reset}\n`);

    // Check system requirements
    this.checkNodeVersion();
    this.checkNpmVersion();
    this.checkMySQLVersion();
    this.checkNginxVersion();
    this.checkCertbotVersion();

    // Check port availability
    await this.checkPortAvailable(DEFAULT_PORT);

    // Check GeoIP database
    this.checkGeoIPDatabase();

    // Check permissions
    this.checkPermissions();

    // Print summary
    this.printSummary();

    // Exit with appropriate code
    if (this.errors > 0) {
      console.log(`\n${colors.red}${colors.bold}❌ System does not meet requirements. Please fix errors above.${colors.reset}`);
      process.exit(1);
    } else if (this.warnings > 0) {
      console.log(`\n${colors.yellow}${colors.bold}⚠️  Some optional requirements are missing. Installation can proceed.${colors.reset}`);
      process.exit(0);
    } else {
      console.log(`\n${colors.green}${colors.bold}✅ All requirements met! Ready to install.${colors.reset}`);
      process.exit(0);
    }
  }

  /**
   * Execute command and get version
   */
  executeCommand(command) {
    try {
      const output = execSync(command, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
      return output.trim();
    } catch (error) {
      return null;
    }
  }

  /**
   * Parse version string
   */
  parseVersion(versionString) {
    const match = versionString.match(/(\d+)\.(\d+)\.(\d+)/);
    if (match) {
      return {
        major: parseInt(match[1]),
        minor: parseInt(match[2]),
        patch: parseInt(match[3]),
        string: `${match[1]}.${match[2]}.${match[3]}`
      };
    }
    return null;
  }

  /**
   * Compare versions
   */
  compareVersions(current, required) {
    const curr = this.parseVersion(current);
    const req = this.parseVersion(required);

    if (!curr || !req) return false;

    if (curr.major > req.major) return true;
    if (curr.major < req.major) return false;
    if (curr.minor > req.minor) return true;
    if (curr.minor < req.minor) return false;
    return curr.patch >= req.patch;
  }

  /**
   * Check Node.js version
   */
  checkNodeVersion() {
    const version = this.executeCommand(REQUIREMENTS.node.command);
    if (!version) {
      this.logError('Node.js', 'Not installed', REQUIREMENTS.node.min);
      return;
    }

    if (this.compareVersions(version, REQUIREMENTS.node.min)) {
      this.logSuccess('Node.js', this.parseVersion(version).string, REQUIREMENTS.node.min);
    } else {
      this.logError('Node.js', this.parseVersion(version).string, REQUIREMENTS.node.min);
    }
  }

  /**
   * Check npm version
   */
  checkNpmVersion() {
    const version = this.executeCommand(REQUIREMENTS.npm.command);
    if (!version) {
      this.logError('npm', 'Not installed', REQUIREMENTS.npm.min);
      return;
    }

    if (this.compareVersions(version, REQUIREMENTS.npm.min)) {
      this.logSuccess('npm', this.parseVersion(version).string, REQUIREMENTS.npm.min);
    } else {
      this.logError('npm', this.parseVersion(version).string, REQUIREMENTS.npm.min);
    }
  }

  /**
   * Check MySQL/MariaDB version
   */
  checkMySQLVersion() {
    const version = this.executeCommand(REQUIREMENTS.mysql.command);
    if (!version) {
      this.logError('MySQL/MariaDB', 'Not installed', REQUIREMENTS.mysql.min);
      return;
    }

    // Try to parse MariaDB or MySQL version
    const parsed = this.parseVersion(version);
    if (parsed && this.compareVersions(parsed.string, REQUIREMENTS.mysql.min)) {
      this.logSuccess('MySQL/MariaDB', parsed.string, REQUIREMENTS.mysql.min);
    } else {
      this.logWarning('MySQL/MariaDB', parsed ? parsed.string : 'Unknown', REQUIREMENTS.mysql.min);
    }
  }

  /**
   * Check Nginx version (optional)
   */
  checkNginxVersion() {
    const version = this.executeCommand(REQUIREMENTS.nginx.command);
    if (!version) {
      this.logWarning('Nginx', 'Not installed (optional)', REQUIREMENTS.nginx.min, true);
      return;
    }

    const parsed = this.parseVersion(version);
    if (parsed) {
      this.logSuccess('Nginx', parsed.string, REQUIREMENTS.nginx.min, true);
    } else {
      this.logWarning('Nginx', 'Installed but version unknown', REQUIREMENTS.nginx.min, true);
    }
  }

  /**
   * Check Certbot version (optional)
   */
  checkCertbotVersion() {
    const version = this.executeCommand(REQUIREMENTS.certbot.command);
    if (!version) {
      this.logWarning('Certbot', 'Not installed (optional)', 'any', true);
      return;
    }

    const parsed = this.parseVersion(version);
    if (parsed) {
      this.logSuccess('Certbot', parsed.string, 'any', true);
    } else {
      this.logWarning('Certbot', 'Installed but version unknown', 'any', true);
    }
  }

  /**
   * Check if port is available
   */
  async checkPortAvailable(port) {
    return new Promise((resolve) => {
      const server = net.createServer();

      server.once('error', (err) => {
        if (err.code === 'EADDRINUSE') {
          this.logError('Port Availability', `Port ${port} is in use`, 'Available');
          resolve(false);
        } else if (err.code === 'EACCES') {
          this.logError('Port Permissions', `No permission to bind port ${port}`, 'Root/sudo required');
          resolve(false);
        } else {
          this.logWarning('Port Check', `Error checking port: ${err.message}`, 'Available');
          resolve(false);
        }
      });

      server.once('listening', () => {
        server.close();
        this.logSuccess('Port Availability', `Port ${port}`, 'Available');
        resolve(true);
      });

      server.listen(port);
    });
  }

  /**
   * Check GeoIP database
   */
  checkGeoIPDatabase() {
    const GEOIP_PATH = '/usr/share/GeoIP/GeoLite2-Country.mmdb';

    // Check if file exists
    if (!fs.existsSync(GEOIP_PATH)) {
      this.logWarning('GeoIP Database', 'Not found (tracking will be disabled)', 'Optional');
      console.log(`    ${colors.blue}ℹ  Install GeoIP database with: sudo bash scripts/update-geoip.sh${colors.reset}`);
      return;
    }

    // Check read permissions
    try {
      fs.accessSync(GEOIP_PATH, fs.constants.R_OK);
      this.logSuccess('GeoIP Database', GEOIP_PATH, 'Optional');
    } catch (error) {
      this.logWarning('GeoIP Database', 'Found but not readable', 'Optional');
      console.log(`    ${colors.blue}ℹ  Fix permissions with: sudo chmod 644 ${GEOIP_PATH}${colors.reset}`);
    }
  }

  /**
   * Check write permissions
   */
  checkPermissions() {
    const testDirs = [
      process.cwd(),
      `${process.cwd()}/config`,
      `${process.cwd()}/logs`
    ];

    let allWritable = true;

    for (const dir of testDirs) {
      try {
        // Create directory if it doesn't exist
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }

        // Test write permissions
        const testFile = `${dir}/.write-test-${Date.now()}`;
        fs.writeFileSync(testFile, 'test');
        fs.unlinkSync(testFile);
      } catch (error) {
        allWritable = false;
        this.logError('File Permissions', `Cannot write to ${dir}`, 'Write access required');
      }
    }

    if (allWritable) {
      this.logSuccess('File Permissions', 'All directories writable', 'Write access');
    }
  }

  /**
   * Log success
   */
  logSuccess(name, current, required, optional = false) {
    const label = optional ? `${name} (optional)` : name;
    console.log(`${colors.green}✓${colors.reset} ${label.padEnd(25)} ${colors.green}${current}${colors.reset} (>= ${required})`);
    this.results.push({ name, status: 'ok', current, required });
  }

  /**
   * Log error
   */
  logError(name, current, required) {
    console.log(`${colors.red}✗${colors.reset} ${name.padEnd(25)} ${colors.red}${current}${colors.reset} (requires >= ${required})`);
    this.results.push({ name, status: 'error', current, required });
    this.errors++;
  }

  /**
   * Log warning
   */
  logWarning(name, current, required, optional = false) {
    const label = optional ? name : `${name} (warning)`;
    console.log(`${colors.yellow}⚠${colors.reset} ${label.padEnd(25)} ${colors.yellow}${current}${colors.reset} (recommended >= ${required})`);
    this.results.push({ name, status: 'warning', current, required });
    this.warnings++;
  }

  /**
   * Print summary
   */
  printSummary() {
    console.log(`\n${colors.bold}Summary:${colors.reset}`);
    console.log(`  ${colors.green}✓ Passed:${colors.reset} ${this.results.filter(r => r.status === 'ok').length}`);
    if (this.warnings > 0) {
      console.log(`  ${colors.yellow}⚠ Warnings:${colors.reset} ${this.warnings}`);
    }
    if (this.errors > 0) {
      console.log(`  ${colors.red}✗ Errors:${colors.reset} ${this.errors}`);
    }
  }
}

// Run checker
if (require.main === module) {
  const checker = new RequirementsChecker();
  checker.check().catch(error => {
    console.error(`${colors.red}Error during requirements check:${colors.reset}`, error.message);
    process.exit(1);
  });
}

module.exports = RequirementsChecker;
