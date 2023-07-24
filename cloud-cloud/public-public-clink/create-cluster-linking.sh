#!/bin/bash
source ../.env

cat <<EOF >> clink.properties
bootstrap.servers=$CCLOUD_SRC_URL
security.protocol=SASL_SSL
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='$CCLOUD_SRC_APIKEY' password='$CCLOUD_SRC_PASSWD';
sasl.mechanism=PLAIN
client.dns.lookup=use_all_dns_ips
session.timeout.ms=45000
EOF

confluent kafka link create migrations-clink \
    --config-file clink.properties \
    --environment "$ENV" \
    --cluster "$CCLOUD_DST_CLUSTERID"