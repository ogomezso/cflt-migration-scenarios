#!/bin/bash
source ../.env

confluent kafka link delete migrations-clink \
    --environment "$ENV" \
    --cluster "$CCLOUD_DST_CLUSTERID"