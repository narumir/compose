#!/bin/sh
# Substitute environment variables in the pipeline template before starting Data Prepper.
# Data Prepper 2.x does not natively substitute ${VAR} in pipelines.yaml, so we preprocess it.

set -e

TEMPLATE=/tmp/pipelines.yaml.tmpl
TARGET=/usr/share/data-prepper/pipelines/pipelines.yaml

if [ ! -f "$TEMPLATE" ]; then
  echo "[entrypoint] Template not found: $TEMPLATE" >&2
  exit 1
fi

sed "s|\${OPENSEARCH_PASSWORD}|${OPENSEARCH_PASSWORD}|g" "$TEMPLATE" > "$TARGET"

echo "[entrypoint] Rendered pipelines.yaml from template."

exec /usr/share/data-prepper/bin/data-prepper
