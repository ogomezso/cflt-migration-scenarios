#!/bin/bash
source ../.env

confluent kafka mirror failover $TOPIC --link migrations-clink --environment $ENV --cluster $CCLOUD_DST_CLUSTERID
