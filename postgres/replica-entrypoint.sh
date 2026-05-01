#!/bin/bash
set -e

# PG18+ uses version-specific subdirectory (e.g. /var/lib/postgresql/18/main)
: "${PGDATA:=/var/lib/postgresql/18/main}"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Replica: waiting for primary..."
    until PGPASSWORD="${REPLICATION_PASSWORD}" pg_isready -h postgres-primary -p 5432 -U "${REPLICATION_USER}" 2>/dev/null; do
        sleep 2
    done

    echo "Replica: starting pg_basebackup..."
    PGPASSWORD="${REPLICATION_PASSWORD}" pg_basebackup \
        -h postgres-primary \
        -p 5432 \
        -U "${REPLICATION_USER}" \
        -D "${PGDATA}" \
        -Fp -Xs -P -R \
        -S replica_slot

    chmod 0700 "${PGDATA}"
    echo "Replica: bootstrap complete."
fi

exec postgres -c config_file=/etc/postgresql/postgresql.conf -c hot_standby=on

