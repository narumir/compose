FROM postgres:18.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-18-pgvector \
        postgresql-18-postgis-3 \
        postgresql-18-pgaudit \
        postgresql-contrib-18 \
    && rm -rf /var/lib/apt/lists/*
