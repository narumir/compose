-- ---------------------------------------------------------------------------
-- Text search and similarity
-- - pg_trgm: trigram-based LIKE/ILIKE and similarity search acceleration
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------------
-- Geospatial
-- - postgis: spatial types/functions
-- - postgis_topology: topology model support
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- ---------------------------------------------------------------------------
-- Auditing and observability
-- - pgaudit: detailed SQL audit logging
-- - pg_stat_statements: query statistics for performance analysis
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgaudit;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ---------------------------------------------------------------------------
-- Vector search
-- - vector: embedding/vector type and ANN index support
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;
