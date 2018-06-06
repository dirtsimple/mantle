FROM dirtsimple/php-server:1.2.9

ENV RUN_SCRIPTS    "bin/startup"
ENV PHP_CONTROLLER "true"
ENV PHP_MEM_LIMIT  "256"

ENV PUBLIC_DIR "public"

ENV NGINX_OWNED    "public/ext/uploads"
ENV NGINX_WRITABLE "public/ext/uploads"
ENV NGINX_READBLE  "public vendor"
ENV NGINX_NO_WRITE "."
ENV EXCLUDE_PHP    "/ext/uploads"

ENV PAGER "less"

ENV IMPOSER_THEMES   "public/ext/themes"
ENV IMPOSER_PLUGINS  "public/ext/plugins"
ENV IMPOSER_VENDOR   "vendor"
ENV IMPOSER_PACKAGES "/home/developer/.wp-cli/packages"
ENV IMPOSER_GLOBALS  "/composer/vendor"

RUN EXTRA_APKS="less jq nano bind-tools mysql-client py-pygments git-perl" install-extras \
    && composer-global psy/psysh:@stable dirtsimple/imposer:dev-master dirtsimple/postmark:dev-master
