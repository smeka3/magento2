#!/bin/bash

DC="docker compose"
APP="app"

# Run Magento CLI
m() { $DC exec $APP php bin/magento "$@"; }

case "$1" in
    # Containers
    up|start) $DC up -d ;;
    down|stop) $DC down ;;
    restart) $DC restart ;;
    ps|status) $DC ps ;;
    logs) $DC logs -f ${2:-$APP} ;;
    
    # Cache
    cf|flush) m cache:flush ;;
    cc|clean) m cache:clean ;;
    
    # Deploy
    deploy) m setup:static-content:deploy ${2:-en_US} -f ;;
    upgrade) m setup:upgrade ;;
    compile) m setup:di:compile ;;
    reindex) m indexer:reindex ;;
    quick)
        m setup:upgrade && \
        m setup:di:compile && \
        m setup:static-content:deploy -f && \
        m cache:flush
        ;;
    
    # Mode
    dev) m deploy:mode:set developer ;;
    prod) m deploy:mode:set production ;;
    
    # Clean
    clean)
        $DC exec $APP rm -rf var/cache/* var/page_cache/* generated/code/* generated/metadata/*
        ;;
    clean-all)
        $DC exec $APP rm -rf var/cache/* var/page_cache/* generated/* pub/static/*
        ;;
    
    # Database
    db) $DC exec db mysql -u root -proot magento2 ;;
    backup)
        FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
        $DC exec db mysqldump -u root -proot magento2 > $FILE
        echo "Backup: $FILE"
        ;;
    
    # Shell / Files
    sh|shell) $DC exec $APP bash ;;
    ll) $DC exec $APP ls -la ${2:-.} ;;
    
    # Admin
    admin)
        if [ -z "$2" ]; then
            echo "Usage: $0 admin <username> <password> <email>"
            exit 1
        fi
        m admin:user:create --admin-user="$2" --admin-password="$3" --admin-email="$4" --admin-firstname="Admin" --admin-lastname="User"
        ;;
    
    # Config
    config)
        if [ -z "$2" ]; then
            echo "Usage: $0 config <path> [value]"
            exit 1
        fi
        [ -z "$3" ] && m config:show $2 || m config:set $2 $3
        ;;

    # Permissions
    perms)
      $DC exec $APP sh -lc "chown -R www-data:www-data var generated pub/static pub/media app/etc && \
        find var generated pub/static pub/media app/etc -type f -exec chmod 664 {} \\; && \
        find var generated pub/static pub/media app/etc -type d -exec chmod 775 {} \\;"
      ;;
    
    # Composer
    composer) shift; $DC exec $APP composer "$@" ;;
    
    # Direct Magento CLI
    m|cli) shift; m "$@" ;;
    
    # Help
    *)
        cat << 'EOF'
Magento Docker Commands
=======================

Containers:
  up/start              Start containers
  down/stop             Stop containers  
  restart               Restart containers
  ps/status             Show status
  logs [service]        Show logs

Cache:
  cf/flush              Flush cache
  cc/clean              Clean cache

Deploy:
  deploy [locale]       Deploy static (default: en_US)
  upgrade               Run setup:upgrade
  compile               Run DI compile
  reindex               Reindex all
  quick                 Full deploy (upgrade+compile+deploy+flush)

Mode:
  dev                   Developer mode
  prod                  Production mode

Clean:
  clean                 Clean cache/generated
  clean-all             Clean everything

Database:
  db                    MySQL shell
  backup                Backup database

Shell:
  sh/shell              Bash shell
  ll [path]             ls -la (default: .)

Admin:
  admin <user> <pass> <email>  Create admin user

Config:
  config <path> [value]         Show/set config

Permissions:
  perms                 Fix writable dirs (www-data, 664/775)

Other:
  composer [cmd]        Run composer
  m/cli [cmd]           Run any Magento CLI command

Examples:
  ./m.sh up
  ./m.sh cf
  ./m.sh deploy
  ./m.sh quick
  ./m.sh admin user Pass123! user@test.com
  ./m.sh config dev/static/sign 0
  ./m.sh m module:status
EOF
        ;;
esac
