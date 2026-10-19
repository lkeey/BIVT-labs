#!/usr/bin/env bash
# Create a private local CA and a localhost certificate for SQL Server.
# Run once as root on the VPS, after installing mssql-server.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  printf 'Run as root (for example, with sudo).\n' >&2
  exit 1
fi
if [[ ! -x /opt/mssql/bin/mssql-conf ]] || ! id mssql >/dev/null 2>&1; then
  printf 'Install and configure mssql-server before setting up TLS.\n' >&2
  exit 1
fi
if [[ ! -f 03SQL-CourseWork/deploy/vps/sql-local.ext ]]; then
  printf 'Run from the root of the BIVT-labs checkout.\n' >&2
  exit 1
fi

ca_key=/etc/sql-coursework/sql-local-ca.key
ca_cert=/usr/local/share/ca-certificates/sql-coursework-local-ca.crt
server_dir=/var/opt/mssql/sslcert
server_key="${server_dir}/sql-local.key"
server_cert="${server_dir}/sql-local.crt"

for file in "$ca_key" "$ca_cert" "$server_key" "$server_cert"; do
  if [[ -e "$file" ]]; then
    printf 'Refusing to replace existing certificate material: %s\n' "$file" >&2
    exit 1
  fi
done

install -d -o root -g root -m 0755 /etc/sql-coursework
install -d -o mssql -g mssql -m 0700 "$server_dir"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
umask 077

openssl req -x509 -newkey rsa:3072 -noenc -sha256 -days 365 \
  -subj '/CN=SQL Coursework Local CA' \
  -addext 'basicConstraints=critical,CA:TRUE' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -keyout "$ca_key" -out "$ca_cert"
openssl req -new -newkey rsa:3072 -noenc -sha256 \
  -subj '/CN=localhost' -keyout "$server_key" -out "$tmp_dir/server.csr"
openssl x509 -req -in "$tmp_dir/server.csr" -CA "$ca_cert" \
  -CAkey "$ca_key" -CAserial "$tmp_dir/ca.srl" -CAcreateserial \
  -days 365 -sha256 \
  -extfile 03SQL-CourseWork/deploy/vps/sql-local.ext \
  -extensions v3_server -out "$server_cert"

chown mssql:mssql "$server_key" "$server_cert"
chmod 0600 "$ca_key" "$server_key"
chmod 0644 "$ca_cert" "$server_cert"
openssl verify -verify_hostname localhost -CAfile "$ca_cert" "$server_cert"
update-ca-certificates
/opt/mssql/bin/mssql-conf set network.tlscert "$server_cert"
/opt/mssql/bin/mssql-conf set network.tlskey "$server_key"
systemctl restart mssql-server
printf 'SQL Server now has a localhost certificate. Verify with sqlcmd -S localhost -Nm (without -C).\n'
