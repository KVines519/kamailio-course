FROM ghcr.io/kamailio/kamailio-ci:6.1.2-alpine
RUN apk add --no-cache mariadb-client ca-certificates
COPY db-certs/ca.crt /usr/local/share/ca-certificates/internal-ca.crt
RUN update-ca-certificates
