FROM sentry:9.1.2-onbuild
RUN apt-get update
RUN apt-get -y install dnsutils
RUN apt-get -y install redis-tools
RUN apt-get -y install wget

WORKDIR /usr/src/sentry

# Add WORKDIR to PYTHONPATH so local python files don't need to be installed
ENV PYTHONPATH /usr/src/sentry
COPY . /usr/src/sentry

RUN mv /usr/src/sentry/entrypoint.sh /entrypoint.sh

# Hook for installing additional plugins
RUN if [ -s requirements.txt ]; then pip install -r requirements.txt; fi

# Hook for installing a local app as an addon
RUN if [ -s setup.py ]; then pip install -e .; fi

# Hook for staging in custom configs
RUN if [ -s sentry.conf.py ]; then cp sentry.conf.py $SENTRY_CONF/; fi \
	&& if [ -s config.yml ]; then cp config.yml $SENTRY_CONF/; fi
