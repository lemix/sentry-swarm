from __future__ import absolute_import

# This file is just Python, with a touch of Django which means
# you can inherit and tweak settings to your hearts content.

# For Docker, the following environment variables are supported:
#  SENTRY_DB_HOST
#  SENTRY_DB_PORT
#  SENTRY_DB_NAME
#  SENTRY_DB_USER
#  SENTRY_DB_PASSWORD
#  SENTRY_REDIS_HOST
#  SENTRY_REDIS_PASSWORD
#  SENTRY_REDIS_PORT
#  SENTRY_REDIS_DB
#  SENTRY_FILESTORE_DIR
#  SENTRY_SINGLE_ORGANIZATION
#  SENTRY_SECRET_KEY
from sentry.conf.server import *
from sentry.utils.types import Bool

import os
import os.path

CONF_ROOT = os.path.dirname(__file__)
env = os.environ.get

SENTRY_OPTIONS['system.secret-key'] = env('SENTRY_SECRET_KEY')

DATABASES = {
    "default": {
        "ENGINE": "sentry.db.postgres",
        "NAME": env('SENTRY_DB_NAME'),
        "USER": env('SENTRY_DB_USER'),
        "PASSWORD": env('SENTRY_DB_PASSWORD'),
        "HOST": env('SENTRY_DB_HOST'),
        "PORT": env('SENTRY_DB_PORT') or '5432',
    }
}

SENTRY_USE_BIG_INTS = True

SENTRY_SINGLE_ORGANIZATION = True

redis = env('SENTRY_REDIS_HOST')
redis_password = env('SENTRY_REDIS_PASSWORD') or ''
redis_port = env('SENTRY_REDIS_PORT') or '6379'
redis_db = env('SENTRY_REDIS_DB') or '0'

SENTRY_OPTIONS.update({
    'redis.clusters': {
        'default': {
            'hosts': {
                0: {
                    'host': redis,
                    'password': redis_password,
                    'port': redis_port,
                    'db': redis_db,
                },
            },
        },
    },
})

SENTRY_CACHE = 'sentry.cache.redis.RedisCache'

BROKER_URL = "redis://:{password}@{host}:{port}/{db}".format(
    **SENTRY_OPTIONS["redis.clusters"]["default"]["hosts"][0]
)

SENTRY_RATELIMITER = 'sentry.ratelimits.redis.RedisRateLimiter'

SENTRY_BUFFER = 'sentry.buffer.redis.RedisBuffer'

SENTRY_QUOTAS = 'sentry.quotas.redis.RedisQuota'

SENTRY_TSDB = 'sentry.tsdb.redis.RedisTSDB'

if Bool(env('SENTRY_USE_SSL', False)):
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

SENTRY_WEB_HOST = "0.0.0.0"
SENTRY_WEB_PORT = 9000
SENTRY_WEB_OPTIONS = {
    "http": "%s:%s" % (SENTRY_WEB_HOST, SENTRY_WEB_PORT),
    "protocol": "uwsgi",
    # This is needed to prevent https://git.io/fj7Lw
    "uwsgi-socket": None,
    "http-keepalive": True,
    "memory-report": False,
    "workers": 1
}

email = env('SENTRY_EMAIL_HOST') or (env('SMTP_PORT_25_TCP_ADDR') and 'smtp')
if email:
    SENTRY_OPTIONS['mail.backend'] = 'smtp'
    SENTRY_OPTIONS['mail.host'] = email
    SENTRY_OPTIONS['mail.password'] = env('SENTRY_EMAIL_PASSWORD') or ''
    SENTRY_OPTIONS['mail.username'] = env('SENTRY_EMAIL_USER') or ''
    SENTRY_OPTIONS['mail.port'] = int(env('SENTRY_EMAIL_PORT') or 25)
    SENTRY_OPTIONS['mail.use-tls'] = bool(env('SENTRY_EMAIL_USE_TLS'))
    SENTRY_OPTIONS['mail.list-namespace'] = env('SENTRY_EMAIL_LIST_NAMESPACE') or 'localhost'
else:
    SENTRY_OPTIONS['mail.backend'] = 'dummy'

SENTRY_OPTIONS['mail.from'] = env('SENTRY_SERVER_EMAIL') or 'root@localhost'

SENTRY_SECRET_KEY = env('SENTRY_SECRET_KEY')