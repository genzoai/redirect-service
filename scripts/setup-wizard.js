#!/usr/bin/env node

/**
 * Universal Redirect Service - Interactive Setup Wizard
 * Generates configuration files (.env, sites.json, utm-sources.json)
 */

const inquirer = require('inquirer');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m'
};

class SetupWizard {
  constructor() {
    this.config = {
      sites: {},
      utmSources: {},
      env: {}
    };
    this.rootDir = path.resolve(__dirname, '..');
  }

  /**
   * Main setup flow
   */
  async run() {
    console.log(`${colors.bold}${colors.blue}`);
    console.log('╔════════════════════════════════════════════════════════╗');
    console.log('║   Universal Redirect Service - Setup Wizard           ║');
    console.log('╚════════════════════════════════════════════════════════╝');
    console.log(`${colors.reset}\n`);

    try {
      // Step 1: Server configuration
      await this.setupServer();

      // Step 2: Database configuration
      await this.setupDatabase();

      // Step 3: Add sites
      await this.setupSites();

      // Step 4: Setup UTM sources
      await this.setupUTMSources();

      // Step 5: Additional settings
      await this.setupAdditionalSettings();

      // Step 6: Generate files
      await this.generateFiles();

      // Success message
      this.printSuccess();

    } catch (error) {
      console.error(`\n${colors.red}${colors.bold}Error during setup:${colors.reset}`, error.message);
      process.exit(1);
    }
  }

  /**
   * Step 1: Server Configuration
   */
  async setupServer() {
    console.log(`${colors.cyan}${colors.bold}Step 1: Server Configuration${colors.reset}\n`);

    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'domain',
        message: 'Enter your domain/subdomain for the redirect service:',
        default: 'go.example.com',
        validate: (input) => {
          if (!input || input.trim().length === 0) {
            return 'Domain is required';
          }
          // Basic domain validation
          if (!/^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}$/i.test(input)) {
            return 'Please enter a valid domain';
          }
          return true;
        }
      },
      {
        type: 'input',
        name: 'port',
        message: 'Enter the port for the service:',
        default: '3077',
        validate: (input) => {
          const port = parseInt(input);
          if (isNaN(port) || port < 1 || port > 65535) {
            return 'Please enter a valid port number (1-65535)';
          }
          return true;
        }
      }
    ]);

    this.config.env.PORT = answers.port;
    this.config.serverDomain = answers.domain;
  }

  /**
   * Step 2: Database Configuration
   */
  async setupDatabase() {
    console.log(`\n${colors.cyan}${colors.bold}Step 2: Database Configuration${colors.reset}\n`);

    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'dbHost',
        message: 'Database host:',
        default: 'localhost'
      },
      {
        type: 'input',
        name: 'dbPort',
        message: 'Database port:',
        default: '3306'
      },
      {
        type: 'input',
        name: 'dbName',
        message: 'Database name for redirect service:',
        default: 'redirect_db'
      },
      {
        type: 'input',
        name: 'dbUser',
        message: 'Database user:',
        default: 'redirect_user'
      },
      {
        type: 'password',
        name: 'dbPassword',
        message: 'Database password:',
        mask: '*'
      },
      {
        type: 'password',
        name: 'dbRootPassword',
        message: 'Database root password (for initial setup):',
        mask: '*'
      }
    ]);

    this.config.env.DB_HOST = answers.dbHost;
    this.config.env.DB_PORT = answers.dbPort;
    this.config.env.DB_NAME = answers.dbName;
    this.config.env.DB_USER = answers.dbUser;
    this.config.env.DB_PASSWORD = answers.dbPassword;
    this.config.env.DB_ROOT_PASSWORD = answers.dbRootPassword;
  }

  /**
   * Step 3: Setup Sites
   */
  async setupSites() {
    console.log(`\n${colors.cyan}${colors.bold}Step 3: Site Configuration${colors.reset}\n`);

    let addMore = true;

    while (addMore) {
      const siteAnswers = await inquirer.prompt([
        {
          type: 'input',
          name: 'siteId',
          message: 'Site ID (slug, e.g., "mysite"):',
          validate: (input) => {
            if (!input || !/^[a-z0-9_-]+$/i.test(input)) {
              return 'Site ID must contain only letters, numbers, dashes and underscores';
            }
            if (this.config.sites[input]) {
              return 'This Site ID already exists';
            }
            return true;
          }
        },
        {
          type: 'input',
          name: 'domain',
          message: 'Site domain (e.g., "example.com"):',
          validate: (input) => {
            if (!input || input.trim().length === 0) {
              return 'Domain is required';
            }
            return true;
          }
        },
        {
          type: 'list',
          name: 'ogMethod',
          message: 'OG fetching method:',
          choices: [
            { name: 'WordPress Database (direct DB access)', value: 'wordpress_db' },
            { name: 'HTML Fetch (parse OG tags from HTML)', value: 'html_fetch' }
          ],
          default: 'html_fetch'
        }
      ]);

      // If WordPress DB method, ask for DB name
      let wpDbName = null;
      if (siteAnswers.ogMethod === 'wordpress_db') {
        const wpAnswers = await inquirer.prompt([
          {
            type: 'input',
            name: 'wpDbName',
            message: 'WordPress database name:',
            validate: (input) => input.trim().length > 0 ? true : 'Database name is required'
          }
        ]);
        wpDbName = wpAnswers.wpDbName;
      }

      // Add description
      const descAnswers = await inquirer.prompt([
        {
          type: 'input',
          name: 'description',
          message: 'Site description (optional):',
          default: ''
        }
      ]);

      // Build site config
      const siteConfig = {
        domain: siteAnswers.domain,
        og_method: siteAnswers.ogMethod,
        description: descAnswers.description || `${siteAnswers.domain} redirect configuration`
      };

      if (wpDbName) {
        siteConfig.wp_db = wpDbName;
      }

      this.config.sites[siteAnswers.siteId] = siteConfig;

      console.log(`${colors.green}✓ Site "${siteAnswers.siteId}" added${colors.reset}`);

      // Ask if want to add more
      const moreAnswers = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'addMore',
          message: 'Add another site?',
          default: false
        }
      ]);

      addMore = moreAnswers.addMore;
    }
  }

  /**
   * Step 4: Setup UTM Sources
   */
  async setupUTMSources() {
    console.log(`\n${colors.cyan}${colors.bold}Step 4: Traffic Sources (UTM)${colors.reset}\n`);

    // Default sources
    const defaultSources = {
      fb: { utm_medium: 'social', utm_source: 'facebook' },
      ig: { utm_medium: 'social', utm_source: 'instagram' },
      tiktok: { utm_medium: 'social', utm_source: 'tiktok' },
      tg: { utm_medium: 'messenger', utm_source: 'telegram' },
      email: { utm_medium: 'email', utm_source: 'newsletter' }
    };

    const answers = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'useDefaults',
        message: 'Use default traffic sources (fb, ig, tiktok, tg, email)?',
        default: true
      }
    ]);

    if (answers.useDefaults) {
      this.config.utmSources = { ...defaultSources };
      console.log(`${colors.green}✓ Default traffic sources added${colors.reset}`);
    }

    // Ask if want to add custom sources
    const customAnswers = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'addCustom',
        message: 'Add custom traffic sources?',
        default: false
      }
    ]);

    if (customAnswers.addCustom) {
      let addMore = true;

      while (addMore) {
        const sourceAnswers = await inquirer.prompt([
          {
            type: 'input',
            name: 'slug',
            message: 'Source slug (e.g., "linkedin"):',
            validate: (input) => {
              if (!input || !/^[a-z0-9_-]+$/i.test(input)) {
                return 'Slug must contain only letters, numbers, dashes and underscores';
              }
              if (this.config.utmSources[input]) {
                return 'This source already exists';
              }
              return true;
            }
          },
          {
            type: 'input',
            name: 'utmSource',
            message: 'UTM source value:',
            validate: (input) => input.trim().length > 0 ? true : 'UTM source is required'
          },
          {
            type: 'list',
            name: 'utmMedium',
            message: 'UTM medium:',
            choices: ['social', 'messenger', 'email', 'referral', 'paid', 'organic'],
            default: 'social'
          }
        ]);

        this.config.utmSources[sourceAnswers.slug] = {
          utm_medium: sourceAnswers.utmMedium,
          utm_source: sourceAnswers.utmSource
        };

        console.log(`${colors.green}✓ Source "${sourceAnswers.slug}" added${colors.reset}`);

        const moreAnswers = await inquirer.prompt([
          {
            type: 'confirm',
            name: 'addMore',
            message: 'Add another source?',
            default: false
          }
        ]);

        addMore = moreAnswers.addMore;
      }
    }
  }

  /**
   * Step 5: Additional Settings
   */
  async setupAdditionalSettings() {
    console.log(`\n${colors.cyan}${colors.bold}Step 5: Additional Settings${colors.reset}\n`);

    const answers = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'enableGeoIP',
        message: 'Enable GeoIP country tracking?',
        default: true
      },
      {
        type: 'confirm',
        name: 'setupSSL',
        message: 'Setup SSL certificate (Let\'s Encrypt)?',
        default: true
      },
      {
        type: 'input',
        name: 'apiBearerToken',
        message: 'API Token for n8n (leave empty to generate):',
        default: ''
      }
    ]);

    this.config.env.GEOIP_ENABLED = answers.enableGeoIP ? 'true' : 'false';
    this.config.setupSSL = answers.setupSSL;

    // Generate or use provided API token
    if (answers.apiBearerToken && answers.apiBearerToken.trim().length > 0) {
      this.config.env.API_TOKEN = answers.apiBearerToken.trim();
    } else {
      this.config.env.API_TOKEN = this.generateToken();
      console.log(`${colors.yellow}Generated API Token: ${this.config.env.API_TOKEN}${colors.reset}`);
    }

    // WordPress DB settings (optional)
    if (this.hasWordPressSites()) {
      console.log(`\n${colors.yellow}WordPress database access required for some sites${colors.reset}\n`);

      const wpAnswers = await inquirer.prompt([
        {
          type: 'input',
          name: 'wpDbHost',
          message: 'WordPress database host:',
          default: 'localhost'
        },
        {
          type: 'input',
          name: 'wpDbPort',
          message: 'WordPress database port:',
          default: '3306'
        },
        {
          type: 'input',
          name: 'wpDbUser',
          message: 'WordPress database user (read-only recommended):',
          default: 'wp_readonly'
        },
        {
          type: 'password',
          name: 'wpDbPassword',
          message: 'WordPress database password:',
          mask: '*'
        }
      ]);

      this.config.env.WP_DB_HOST = wpAnswers.wpDbHost;
      this.config.env.WP_DB_PORT = wpAnswers.wpDbPort;
      this.config.env.WP_DB_USER = wpAnswers.wpDbUser;
      this.config.env.WP_DB_PASSWORD = wpAnswers.wpDbPassword;

      // Test WordPress DB connection
      await this.testWordPressDBConnection(wpAnswers);
    }
  }

  /**
   * Check if any sites use WordPress DB
   */
  hasWordPressSites() {
    return Object.values(this.config.sites).some(site => site.og_method === 'wordpress_db');
  }

  /**
   * Test WordPress DB connection
   */
  async testWordPressDBConnection(wpDbConfig) {
    console.log(`\n${colors.cyan}Testing WordPress database connection...${colors.reset}`);

    try {
      // Build MySQL connection test command
      const testCmd = `mysql -h"${wpDbConfig.wpDbHost}" -P"${wpDbConfig.wpDbPort}" -u"${wpDbConfig.wpDbUser}" -p"${wpDbConfig.wpDbPassword}" -e "SELECT 1;" 2>&1`;

      execSync(testCmd, { encoding: 'utf-8', stdio: 'pipe' });

      console.log(`${colors.green}✓ WordPress database connection successful${colors.reset}`);

      // Test access to WordPress databases
      const wpDatabases = Object.values(this.config.sites)
        .filter(site => site.og_method === 'wordpress_db')
        .map(site => site.wp_db);

      if (wpDatabases.length > 0) {
        console.log(`\n${colors.cyan}Testing access to WordPress databases...${colors.reset}`);

        for (const dbName of wpDatabases) {
          try {
            const dbTestCmd = `mysql -h"${wpDbConfig.wpDbHost}" -P"${wpDbConfig.wpDbPort}" -u"${wpDbConfig.wpDbUser}" -p"${wpDbConfig.wpDbPassword}" "${dbName}" -e "SELECT COUNT(*) FROM wp_posts WHERE post_status='publish' LIMIT 1;" 2>&1`;
            execSync(dbTestCmd, { encoding: 'utf-8', stdio: 'pipe' });
            console.log(`${colors.green}  ✓ Database "${dbName}" is accessible${colors.reset}`);
          } catch (error) {
            console.log(`${colors.yellow}  ⚠ Warning: Cannot access database "${dbName}"${colors.reset}`);
            console.log(`${colors.yellow}    Error: ${error.message.split('\n')[0]}${colors.reset}`);
          }
        }
      }

    } catch (error) {
      console.log(`${colors.red}✗ Cannot connect to WordPress database${colors.reset}`);
      console.log(`${colors.yellow}Error: ${error.message.split('\n')[0]}${colors.reset}`);

      const continueAnswers = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'continueAnyway',
          message: `${colors.yellow}WordPress DB connection failed. Continue anyway?${colors.reset}`,
          default: false
        }
      ]);

      if (!continueAnswers.continueAnyway) {
        console.log(`${colors.red}Setup cancelled. Please fix WordPress database connection and try again.${colors.reset}`);
        process.exit(1);
      } else {
        console.log(`${colors.yellow}⚠ Warning: og_method "wordpress_db" will not work until connection is fixed!${colors.reset}`);
      }
    }
  }

  /**
   * Generate random token
   */
  generateToken(length = 32) {
    return crypto.randomBytes(length).toString('hex');
  }

  /**
   * Step 6: Generate configuration files
   */
  async generateFiles() {
    console.log(`\n${colors.cyan}${colors.bold}Step 6: Generating Configuration Files${colors.reset}\n`);

    const configDir = path.join(this.rootDir, 'config');

    // Ensure config directory exists
    if (!fs.existsSync(configDir)) {
      fs.mkdirSync(configDir, { recursive: true });
    }

    // Generate .env
    const envPath = path.join(this.rootDir, '.env');
    const envContent = this.generateEnvFile();
    fs.writeFileSync(envPath, envContent, 'utf8');
    console.log(`${colors.green}✓ Created .env${colors.reset}`);

    // Generate sites.json
    const sitesPath = path.join(configDir, 'sites.json');
    const sitesContent = JSON.stringify(this.config.sites, null, 2);
    fs.writeFileSync(sitesPath, sitesContent, 'utf8');
    console.log(`${colors.green}✓ Created config/sites.json${colors.reset}`);

    // Generate utm-sources.json
    const utmPath = path.join(configDir, 'utm-sources.json');
    const utmContent = JSON.stringify(this.config.utmSources, null, 2);
    fs.writeFileSync(utmPath, utmContent, 'utf8');
    console.log(`${colors.green}✓ Created config/utm-sources.json${colors.reset}`);
  }

  /**
   * Generate .env file content
   */
  generateEnvFile() {
    const lines = [
      '# Universal Redirect Service - Configuration',
      '# Generated by setup wizard',
      '',
      '# Server Configuration',
      'NODE_ENV=production',
      `PORT=${this.config.env.PORT}`,
      '',
      '# Main Database (for clicks logging)',
      `DB_HOST=${this.config.env.DB_HOST}`,
      `DB_PORT=${this.config.env.DB_PORT}`,
      `DB_USER=${this.config.env.DB_USER}`,
      `DB_PASSWORD=${this.config.env.DB_PASSWORD}`,
      `DB_NAME=${this.config.env.DB_NAME}`,
      `DB_ROOT_PASSWORD=${this.config.env.DB_ROOT_PASSWORD}`,
      ''
    ];

    // Add WordPress DB config if needed
    if (this.hasWordPressSites()) {
      lines.push(
        '# WordPress Database (for og_method: wordpress_db)',
        `WP_DB_HOST=${this.config.env.WP_DB_HOST}`,
        `WP_DB_PORT=${this.config.env.WP_DB_PORT}`,
        `WP_DB_USER=${this.config.env.WP_DB_USER}`,
        `WP_DB_PASSWORD=${this.config.env.WP_DB_PASSWORD}`,
        ''
      );
    }

    lines.push(
      '# API Authentication (for n8n and other clients)',
      `API_TOKEN=${this.config.env.API_TOKEN}`,
      '',
      '# GeoIP Settings',
      `GEOIP_ENABLED=${this.config.env.GEOIP_ENABLED}`,
      '',
      '# Logging (optional)',
      'LOG_LEVEL=info',
      'DEBUG=',
      ''
    );

    return lines.join('\n');
  }

  /**
   * Print success message
   */
  printSuccess() {
    console.log(`\n${colors.green}${colors.bold}`);
    console.log('╔════════════════════════════════════════════════════════╗');
    console.log('║              ✓ Setup Complete!                         ║');
    console.log('╚════════════════════════════════════════════════════════╝');
    console.log(`${colors.reset}\n`);

    console.log(`${colors.bold}Configuration files created:${colors.reset}`);
    console.log(`  ${colors.cyan}✓${colors.reset} .env`);
    console.log(`  ${colors.cyan}✓${colors.reset} config/sites.json`);
    console.log(`  ${colors.cyan}✓${colors.reset} config/utm-sources.json`);

    console.log(`\n${colors.bold}Next steps:${colors.reset}`);
    console.log(`  1. Install dependencies: ${colors.yellow}npm install${colors.reset}`);
    console.log(`  2. Setup database: ${colors.yellow}node scripts/setup-database.js${colors.reset}`);
    console.log(`  3. Run migrations: ${colors.yellow}npm run migrate${colors.reset}`);

    if (this.config.setupSSL) {
      console.log(`  4. Setup SSL: ${colors.yellow}sudo bash scripts/setup-ssl.sh ${this.config.serverDomain}${colors.reset}`);
      console.log(`  5. Setup Nginx: ${colors.yellow}sudo bash scripts/setup-nginx.sh${colors.reset}`);
      console.log(`  6. Setup systemd: ${colors.yellow}sudo bash scripts/setup-systemd.sh${colors.reset}`);
    } else {
      console.log(`  4. Setup Nginx: ${colors.yellow}sudo bash scripts/setup-nginx.sh${colors.reset}`);
      console.log(`  5. Setup systemd: ${colors.yellow}sudo bash scripts/setup-systemd.sh${colors.reset}`);
    }

    console.log(`\n${colors.bold}Or run the complete installer:${colors.reset}`);
    console.log(`  ${colors.yellow}sudo bash scripts/install.sh${colors.reset}\n`);

    console.log(`${colors.bold}API Token (save this for n8n):${colors.reset}`);
    console.log(`  ${colors.green}${this.config.env.API_TOKEN}${colors.reset}\n`);
  }
}

// Run wizard
if (require.main === module) {
  const wizard = new SetupWizard();
  wizard.run().catch(error => {
    console.error(`${colors.red}Setup failed:${colors.reset}`, error.message);
    process.exit(1);
  });
}

module.exports = SetupWizard;
