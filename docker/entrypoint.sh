#!/bin/bash

set -e

### Begin swarm ###

# Check redis running

until [ "$REDIS_IS_RUNNING" = "true" ]; do
        echo "Find Redis container"

        redis_ip=$(nslookup $SENTRY_REDIS_HOST 127.0.0.11 | grep 'Address' | tail -n +2 | awk '{print $2}' | tr -d '\n')

        if [ $redis_ip ]; then
                echo "Redis detected on ip $redis_ip"
                if [ "$(redis-cli -h $redis_ip -p 6379 PING)" = "PONG" ]; then
                        echo "Redis is running"
                        REDIS_IS_RUNNING=true
                fi
        fi

        sleep 2
done

# Check pg running

until [ "$PG_IS_RUNNING" = "true" ]; do
        echo "Find PostgreSQL container"

        pg_ip=$(nslookup $SENTRY_DB_HOST 127.0.0.11 | grep 'Address' | tail -n +2 | awk '{print $2}' | tr -d '\n')
        if [ $pg_ip ]; then
                echo "PostgreSQL detected on ip $pg_ip"

                PYTHON_CODE_RET=0
                PYTHON_CODE=$(cat <<END
import psycopg2
try:
    db = psycopg2.connect("dbname='$SENTRY_DB_NAME' user='$SENTRY_DB_USER' host='$SENTRY_DB_HOST' password='$SENTRY_DB_PASSWORD'")
except:
    exit(1)
exit(0)
END
)
                python -c "$PYTHON_CODE" || PYTHON_CODE_RET=$?

                if [ $PYTHON_CODE_RET -eq 0 ]; then
                        echo "PostgreSQL is running and available for connection"
                        PG_IS_RUNNING=true
                else
                        echo "PostgreSQL connection error"
                fi
        fi

        sleep 2
done

# Check sentry web running

if [ "$1" = "run" ] && [ "$2" = "web" ]; then
        echo "Run web"
        IS_WEB=true
else
        echo "Run as not web"
fi

if [ "$IS_WEB" = "true" ]; then
        sentry upgrade

        if [ $? -eq 0 ]; then
                echo "Upgraded"
        fi

        # Check/create organization and user

        sentry shell <<END
# Bootstrap the Sentry environment
from sentry.utils.runner import configure
configure()

# Do something crazy
from sentry.models import (
    User, Organization, OrganizationMember
)

if len(Organization.objects.filter()) == 0:
    organization = Organization()
    organization.name = '$INSTALL_ORG'
    organization.save()
else:
    organization=Organization.objects.filter()[0]
    if organization.name != '$INSTALL_ORG':
        organization.name = '$INSTALL_ORG'
        organization.save()

if len(User.objects.filter()) == 0:
    user = User()
    user.username = '$INSTALL_USERNAME'
    user.email = '$INSTALL_USER_EMAIL'
    user.is_superuser = True
    user.set_password('$INSTALL_USER_PASSWORD')
    user.save()
    member = OrganizationMember.objects.create(organization=organization,user=user,role='owner')

exit()
END

else
        # Wait web container
        until [ "$WEB_IS_RUNNING" = "true" ]; do
                echo "Find Sentry Web container"

                sentry_ip=$(nslookup ${SENTRY_STACK_NAME}_web 127.0.0.11 | grep 'Address' | tail -n +2 | awk '{print $2}' | tr -d '\n')

                if [ $sentry_ip ]; then
                        echo "Sentry Web detected on ip $sentry_ip"

                        exit_code=0
                        wget -O /dev/null "$sentry_ip:9000" || exit_code=$?

                        if [ $exit_code -eq 0 ]; then
                                echo "Sentry Web is running"
                                WEB_IS_RUNNING=true
                        else
                                echo "Sentry Web is not listening"
                        fi
                fi

                sleep 2
        done

fi
### End swarm ###

# first check if we're passing flags, if so
# prepend with sentry
if [ "${1:0:1}" = '-' ]; then
        set -- sentry "$@"
fi

case "$1" in
celery | cleanup | config | createuser | devserver | django | exec | export | help | import | init | plugins | queues | repair | run | shell | start | tsdb | upgrade)
        set -- sentry "$@"
        ;;
esac

if [ "$1" = 'sentry' ]; then
        set -- tini -- "$@"
        if [ "$(id -u)" = '0' ]; then
                mkdir -p "$SENTRY_FILESTORE_DIR"
                chown -R sentry "$SENTRY_FILESTORE_DIR"
                set -- gosu sentry "$@"
        fi
fi

exec "$@"
