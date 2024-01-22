FROM nginx:mainline

# Out-of-the-box, nginx doesn't support environment variables inside most configuration blocks. 
# But this image  (new in 1.19) has a function, which will extract environment variables before nginx starts.

COPY ./default.conf.template /etc/nginx/templates/

RUN mkdir /etc/nginx/tls/

# Replace self-signed cert. files with real ones by injecting them into a spawned container 
RUN /usr/bin/openssl req -x509 -nodes -days 356 -newkey rsa:4096 \
                     -keyout /etc/nginx/tls/cert.key -out /etc/nginx/tls/cert.crt \
                     -subj '/C=US/ST=Oregon/L=Portland/O=IT/CN=guacamole.example.com'

VOLUME /etc/nginx/tls/
