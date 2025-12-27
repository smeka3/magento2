#!/bin/bash
# Magento Docker Management Commands
# Usage: ./magento-docker-commands.sh [command]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

command="${1:-help}"

case "$command" in
    # ============ Container Management ============
    start)
        echo -e "${GREEN}Starting all containers...${NC}"
        docker compose up -d
        ;;
    
    stop)
        echo -e "${YELLOW}Stopping all containers...${NC}"
        docker compose down
        ;;
    
    restart)
        echo -e "${YELLOW}Restarting all containers...${NC}"
        docker compose restart
        ;;
    
    status)
        echo -e "${GREEN}Container status:${NC}"
        docker compose ps
        ;;
    
    logs)
        service="${2:-app}"
        echo -e "${GREEN}Showing logs for ${service}...${NC}"
        docker compose logs -f "$service"
        ;;
    
    # ============ Magento CLI Commands ============
    cli)
        shift
        echo -e "${GREEN}Running: bin/magento $@${NC}"
        docker compose exec app bin/magento "$@"
        ;;
    
    cache-flush)
        echo -e "${GREEN}Flushing Magento cache...${NC}"
        docker compose exec app bin/magento cache:flush
        ;;
    
    cache-clean)
        echo -e "${GREEN}Cleaning Magento cache...${NC}"
        docker compose exec app bin/magento cache:clean
        ;;
    
    cache-disable)
        echo -e "${YELLOW}Disabling all caches...${NC}"
        docker compose exec app bin/magento cache:disable
        ;;
    
    cache-enable)
        echo -e "${GREEN}Enabling all caches...${NC}"
        docker compose exec app bin/magento cache:enable
        ;;
    
    reindex)
        echo -e "${GREEN}Running full reindex...${NC}"
        docker compose exec app bin/magento indexer:reindex
        ;;
    
    reindex-status)
        echo -e "${GREEN}Indexer status:${NC}"
        docker compose exec app bin/magento indexer:status
        ;;
    
    # ============ Mode Management ============
    mode-developer)
        echo -e "${GREEN}Setting developer mode...${NC}"
        docker compose exec app bin/magento deploy:mode:set developer
        ;;
    
    mode-production)
        echo -e "${YELLOW}Setting production mode...${NC}"
        docker compose exec app bin/magento deploy:mode:set production
        ;;
    
    mode-show)
        echo -e "${GREEN}Current mode:${NC}"
        docker compose exec app bin/magento deploy:mode:show
        ;;
    
    # ============ Static Content ============
    static-deploy)
        locale="${2:-en_US}"
        echo -e "${GREEN}Deploying static content for ${locale}...${NC}"
        docker compose exec app bin/magento setup:static-content:deploy -f "$locale"
        ;;
    
    static-clean)
        echo -e "${YELLOW}Cleaning static content...${NC}"
        docker compose exec app rm -rf pub/static/frontend pub/static/adminhtml var/view_preprocessed
        docker compose exec app sh -c 'v=$(cat pub/static/deployed_version.txt 2>/dev/null || date +%s); echo "$v" > pub/static/deployed_version.txt; ln -sfn . "pub/static/version${v}"'
        echo -e "${GREEN}Static content cleaned. Version symlink recreated.${NC}"
        ;;
    
    # ============ Setup & Upgrade ============
    setup-upgrade)
        echo -e "${GREEN}Running setup:upgrade...${NC}"
        docker compose exec app bin/magento setup:upgrade
        ;;
    
    di-compile)
        echo -e "${GREEN}Running dependency injection compilation...${NC}"
        docker compose exec app bin/magento setup:di:compile
        ;;
    
    # ============ Module Management ============
    module-list)
        echo -e "${GREEN}Listing all modules:${NC}"
        docker compose exec app bin/magento module:status
        ;;
    
    module-enable)
        module="${2}"
        if [ -z "$module" ]; then
            echo -e "${RED}Error: Module name required${NC}"
            exit 1
        fi
        echo -e "${GREEN}Enabling module: ${module}${NC}"
        docker compose exec app bin/magento module:enable "$module"
        ;;
    
    module-disable)
        module="${2}"
        if [ -z "$module" ]; then
            echo -e "${RED}Error: Module name required${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Disabling module: ${module}${NC}"
        docker compose exec app bin/magento module:disable "$module"
        ;;
    
    # ============ Database ============
    db-backup)
        echo -e "${GREEN}Creating database backup...${NC}"
        docker compose exec db mysqldump -umagento -pmagento magento > "backup-$(date +%Y%m%d-%H%M%S).sql"
        echo -e "${GREEN}Backup created successfully${NC}"
        ;;
    
    db-restore)
        backup_file="${2}"
        if [ -z "$backup_file" ]; then
            echo -e "${RED}Error: Backup file required${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Restoring database from ${backup_file}...${NC}"
        docker compose exec -T db mysql -umagento -pmagento magento < "$backup_file"
        echo -e "${GREEN}Database restored${NC}"
        ;;
    
    db-shell)
        echo -e "${GREEN}Opening MySQL shell...${NC}"
        docker compose exec db mysql -umagento -pmagento magento
        ;;
    
    db-reset)
        echo -e "${RED}WARNING: This will drop and recreate the database!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            docker compose exec db mysql -uroot -pmagento -e "DROP DATABASE IF EXISTS magento; CREATE DATABASE magento;"
            echo -e "${GREEN}Database reset complete${NC}"
        fi
        ;;
    
    # ============ Composer ============
    composer)
        shift
        echo -e "${GREEN}Running: composer $@${NC}"
        docker compose exec app composer "$@"
        ;;
    
    composer-install)
        echo -e "${GREEN}Installing composer dependencies...${NC}"
        docker compose exec app composer install
        ;;
    
    composer-update)
        echo -e "${GREEN}Updating composer dependencies...${NC}"
        docker compose exec app composer update
        ;;
    
    # ============ Admin User ============
    admin-create)
        echo -e "${GREEN}Creating admin user...${NC}"
        username="${2:-admin}"
        password="${3:-Admin123!}"
        email="${4:-admin@example.com}"
        docker compose exec app bin/magento admin:user:create \
            --admin-user="$username" \
            --admin-password="$password" \
            --admin-email="$email" \
            --admin-firstname="Admin" \
            --admin-lastname="User"
        echo -e "${GREEN}Admin user created: ${username}${NC}"
        ;;
    
    admin-unlock)
        username="${2:-admin}"
        echo -e "${GREEN}Unlocking admin user: ${username}${NC}"
        docker compose exec app bin/magento admin:user:unlock "$username"
        ;;
    
    # ============ Configuration ============
    config-show)
        path="${2}"
        if [ -z "$path" ]; then
            echo -e "${RED}Error: Config path required (e.g., web/unsecure/base_url)${NC}"
            exit 1
        fi
        docker compose exec app bin/magento config:show "$path"
        ;;
    
    config-set)
        path="${2}"
        value="${3}"
        if [ -z "$path" ] || [ -z "$value" ]; then
            echo -e "${RED}Error: Config path and value required${NC}"
            exit 1
        fi
        echo -e "${GREEN}Setting ${path} = ${value}${NC}"
        docker compose exec app bin/magento config:set "$path" "$value"
        ;;
    
    # ============ Cron ============
    cron-run)
        echo -e "${GREEN}Running cron manually...${NC}"
        docker compose exec app bin/magento cron:run
        ;;
    
    cron-install)
        echo -e "${GREEN}Installing cron...${NC}"
        docker compose exec app bin/magento cron:install
        ;;
    
    # ============ Maintenance Mode ============
    maintenance-enable)
        echo -e "${YELLOW}Enabling maintenance mode...${NC}"
        docker compose exec app bin/magento maintenance:enable
        ;;
    
    maintenance-disable)
        echo -e "${GREEN}Disabling maintenance mode...${NC}"
        docker compose exec app bin/magento maintenance:disable
        ;;
    
    maintenance-status)
        echo -e "${GREEN}Maintenance mode status:${NC}"
        docker compose exec app bin/magento maintenance:status
        ;;
    
    # ============ Permissions ============
    fix-permissions)
        echo -e "${GREEN}Fixing file permissions...${NC}"
        docker compose exec app sh -c 'find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + && find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} +'
        echo -e "${GREEN}Permissions fixed${NC}"
        ;;
    
    # ============ Shell Access ============
    shell)
        service="${2:-app}"
        echo -e "${GREEN}Opening shell in ${service} container...${NC}"
        docker compose exec "$service" sh
        ;;
    
    bash)
        echo -e "${GREEN}Opening bash in app container...${NC}"
        docker compose exec app bash
        ;;
    
    # ============ Development ============
    dev-clean)
        echo -e "${YELLOW}Cleaning development files...${NC}"
        docker compose exec app rm -rf var/cache/* var/page_cache/* var/view_preprocessed/* generated/*
        echo -e "${GREEN}Development files cleaned${NC}"
        ;;
    
    full-clean)
        echo -e "${RED}Full clean: cache, static, generated, compiled...${NC}"
        docker compose exec app rm -rf var/cache/* var/page_cache/* var/view_preprocessed/* generated/* pub/static/frontend pub/static/adminhtml
        docker compose exec app sh -c 'v=$(cat pub/static/deployed_version.txt 2>/dev/null || date +%s); echo "$v" > pub/static/deployed_version.txt; ln -sfn . "pub/static/version${v}"'
        docker compose exec app bin/magento cache:flush
        echo -e "${GREEN}Full clean complete${NC}"
        ;;
    
    # ============ Quick Deploy ============
    quick-deploy)
        echo -e "${GREEN}Quick deploy: upgrade + di:compile + static-deploy + cache-flush${NC}"
        docker compose exec app bin/magento setup:upgrade
        docker compose exec app bin/magento setup:di:compile
        docker compose exec app bin/magento setup:static-content:deploy -f en_US
        docker compose exec app bin/magento cache:flush
        echo -e "${GREEN}Quick deploy complete${NC}"
        ;;
    
    # ============ Search/Elasticsearch ============
    search-reindex)
        echo -e "${GREEN}Reindexing search...${NC}"
        docker compose exec app bin/magento indexer:reindex catalogsearch_fulltext
        ;;
    
    # ============ Customer Management ============
    customer-list)
        echo -e "${GREEN}Listing customers:${NC}"
        docker compose exec db mysql -umagento -pmagento magento -e "SELECT entity_id, email, firstname, lastname FROM customer_entity LIMIT 20;"
        ;;
    
    # ============ URL Management ============
    url-rewrite-list)
        echo -e "${GREEN}Listing URL rewrites:${NC}"
        docker compose exec db mysql -umagento -pmagento magento -e "SELECT url_rewrite_id, request_path, target_path, redirect_type FROM url_rewrite LIMIT 20;"
        ;;
    
    # ============ Performance ============
    performance-info)
        echo -e "${GREEN}Performance information:${NC}"
        echo -e "${YELLOW}PHP Memory:${NC}"
        docker compose exec app php -i | grep memory_limit
        echo -e "${YELLOW}OPcache:${NC}"
        docker compose exec app php -i | grep opcache
        echo -e "${YELLOW}Redis:${NC}"
        docker compose exec redis redis-cli INFO stats | grep instantaneous
        ;;
    
    # ============ Help ============
    help|*)
        cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║           Magento Docker Management Commands                   ║
╚════════════════════════════════════════════════════════════════╝

Container Management:
  start                   - Start all containers
  stop                    - Stop all containers
  restart                 - Restart all containers
  status                  - Show container status
  logs [service]          - Show logs (default: app)

Magento CLI:
  cli [command]           - Run any Magento CLI command
  cache-flush             - Flush all caches
  cache-clean             - Clean all caches
  cache-disable           - Disable all caches
  cache-enable            - Enable all caches
  reindex                 - Run full reindex
  reindex-status          - Show indexer status

Mode Management:
  mode-developer          - Set developer mode
  mode-production         - Set production mode
  mode-show               - Show current mode

Static Content:
  static-deploy [locale]  - Deploy static content (default: en_US)
  static-clean            - Clean static content

Setup & Upgrade:
  setup-upgrade           - Run setup:upgrade
  di-compile              - Run DI compilation
  quick-deploy            - Upgrade + compile + deploy + flush

Module Management:
  module-list             - List all modules
  module-enable [name]    - Enable module
  module-disable [name]   - Disable module

Database:
  db-backup               - Create database backup
  db-restore [file]       - Restore from backup
  db-shell                - Open MySQL shell
  db-reset                - Reset database (WARNING: destructive)

Composer:
  composer [cmd]          - Run composer command
  composer-install        - Install dependencies
  composer-update         - Update dependencies

Admin User:
  admin-create [user] [pass] [email] - Create admin user
  admin-unlock [user]     - Unlock admin user

Configuration:
  config-show [path]      - Show config value
  config-set [path] [val] - Set config value

Cron:
  cron-run                - Run cron manually
  cron-install            - Install cron

Maintenance:
  maintenance-enable      - Enable maintenance mode
  maintenance-disable     - Disable maintenance mode
  maintenance-status      - Show maintenance status

Permissions & Shell:
  fix-permissions         - Fix file permissions
  shell [service]         - Open shell (default: app)
  bash                    - Open bash in app container

Development:
  dev-clean               - Clean var/cache, generated, etc.
  full-clean              - Clean everything (cache, static, etc.)

Search:
  search-reindex          - Reindex catalog search

Data Management:
  customer-list           - List customers
  url-rewrite-list        - List URL rewrites

Performance:
  performance-info        - Show PHP/Redis performance info

Examples:
  ./magento-docker-commands.sh start
  ./magento-docker-commands.sh cache-flush
  ./magento-docker-commands.sh cli setup:upgrade
  ./magento-docker-commands.sh admin-create myuser MyPass123! admin@test.com
  ./magento-docker-commands.sh config-set dev/static/sign 0
  ./magento-docker-commands.sh static-deploy en_US
  ./magento-docker-commands.sh db-backup
  ./magento-docker-commands.sh quick-deploy

EOF
        ;;
esac
