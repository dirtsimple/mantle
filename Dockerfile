FROM dirtsimple/php-server:1.3.1

ENV RUN_SCRIPTS    "bin/startup"
ENV PHP_CONTROLLER "true"
ENV PHP_MEM_LIMIT  "256"

ENV PUBLIC_DIR "public"

ENV NGINX_OWNED    "public/ext/uploads"
ENV NGINX_WRITABLE "public/ext/uploads"
ENV NGINX_READABLE "public vendor"
ENV NGINX_NO_WRITE "."
ENV EXCLUDE_PHP    "/ext/uploads"

ENV PAGER "less"

ENV IMPOSER_THEMES   "public/ext/themes"
ENV IMPOSER_PLUGINS  "public/ext/plugins"
ENV IMPOSER_VENDOR   "vendor"
ENV IMPOSER_PACKAGES "/home/developer/.wp-cli/packages/vendor"
ENV IMPOSER_GLOBALS  "/composer/vendor"

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community/" >> /etc/apk/repositories \
    && EXTRA_APKS="less jq nano bind-tools mysql-client py-pygments git-perl colordiff" install-extras \
    && composer-global  psy/psysh:@stable wp-cli/wp-cli dirtsimple/imposer:dev-master dirtsimple/postmark:dev-master
