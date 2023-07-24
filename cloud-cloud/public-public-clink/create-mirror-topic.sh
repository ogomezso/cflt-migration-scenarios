#!/bin/bash
source ../.env

confluent kafka mirror create $TOPIC --link migrations-clink --environment $ENV --source-topic $TOPIC --cluster $CCLOUD_DST_CLUSTERID
