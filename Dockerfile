FROM nginx
COPY html /usr/share/nginx/html
COPY etc/nginx.conf /etc/nginx/nginx.conf
COPY html/nginx_redirects.conf /etc/nginx/conf.d/default.conf
