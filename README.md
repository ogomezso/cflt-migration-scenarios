# cloudera migration environment setup

Date Created: May 19, 2023 9:09 AM
tags: ansible, azure, cloudera, migrations, terraform

# Open Source Kafka to Confluent Platform Migrations Scenarios

Apache Kafka to CP Migration scenarios runbook

# Table of contents
1. [Pre-requisites](#Pre-requisites)
2. [Azure setup](#Azure-setup)
    1. [Log into azure](#Log-into-azure)
3. [Source cluster deployment](#Source-cluster-deployment)
4. [Destination cluster deployment](#Destination-cluster-deployment)
5. [Source resources](#Source-resources)
6. [Cluster linking](#Cluster-linking)

## Pre-requisites

A bastion with ssh access to all hosts has been created

Example:

- Linux (ubuntu 22.04)
- Standard B2s (2 vcpus, 4 GiB memory)
- Same vnet as the virtual machines

The following tools must be installed

```bash
apt-add-repository ppa:ansible/ansible
apt update
apt install make ansible python3-pip kafkacat
# install confluent platform cli
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest
```

The [private key](#Create-key-pair) must be present and have the right permissions

```bash
scp migrations-SSHKey azureuser@20.224.156.254:/home/azureuser/
ssh azureuser@20.224.156.254 -i ~/.ssh/migrations-SSHKey
chmod 400 /home/azureuser/migrations-SSHKey
```
Note: For simplicity, this scenario will use the same key pairs for all the machines, including bastion host

## Azure setup

### Log into azure

```bash
az login
```

### Create resource group and app registration

```bash
az group create --name cloudera-migration --location westeurope \
--tags 'owner_email=ogomezsoriano@confluent.io'

az ad app create --display-name cloudera-migration-app-registration
```

### Find the account id

```bash
# example for a single account present
export ACCOUNT_ID=$(az account list | jq -r '.[0].id')
echo $ACCOUNT_ID
54ff81a0-e7f6-4919-9053-4cdd1c5f5ae1
```

### Set subscription to match the account id

```bash
az account set --subscription "$ACCOUNT_ID"
```

### Create an identity

```bash
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$ACCOUNT_ID"
Creating 'Contributor' role assignment under scope '/subscriptions/54ff81a0-e7f6-4919-9053-4cdd1c5f5ae1'
The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli
{
  "appId": "*** application id ***",
  "displayName": "azure-cli-display-name",
  "password": "*** password ***",
  "tenant": "*** tenant ***"
}
```

### Set environment variables

```bash
export ARM_CLIENT_ID="*** application id ***"
export ARM_CLIENT_SECRET="*** password ***"
export ARM_SUBSCRIPTION_ID="$ACCOUNT_ID"
export ARM_TENANT_ID="*** tenant ***"
```

### Create key pair

```bash
az sshkey create --name "migrations-SSHKey" --resource-group "migrations"

No public key is provided. A key pair is being generated for you.
Private key is saved to "/Users/vcosqui/.ssh/migrations-SSHKey".
Public key is saved to "/Users/vcosqui/.ssh/migrations-SSHKey.pub".
```

### Create network

```bash
az network vnet create \
  --name migrations-vnet \
  --resource-group migrations \
  --address-prefix 10.1.0.0/16
```

## Source cluster deployment

### Set environment variables

```bash
export TF_VAR_pub_key_path="~/.ssh/migrations-SSHKey.pub"
export TF_VAR_resource_group_name="migrations"
export TF_VAR_vnet_name="migrations-vnet"
export TF_VAR_subnet_name="migrations-source-subnet"
export TF_VAR_subnet_addres_prefix="10.1.0.0/24"
export TF_VAR_user_name="kafka"

export TF_VAR_zk_vm_type="Standard_B2ms"
export TF_VAR_zk_data_disk_size=40
export TF_VAR_zk_data_disk_count=1
export TF_VAR_zk_log_disk_size=80
export TF_VAR_broker_vm_type="Standard_B2ms"
export TF_VAR_broker_log_disk_size=80
export TF_VAR_broker_log_disk_count=1
export TF_VAR_sr_count=1
export TF_VAR_connect_count=1
export TF_VAR_ksql_count=1
export TF_VAR_c3_count=1
```

### Prepare and run deployment

```bash
# clone terraform project
git clone git@github.com:ogomezso/tf-cp-cloud-infra-provision.git
cd tf-cp-cloud-infra-provision/azure

# init
terraform init -backend-config "resource_group_name=migrations" \
 -backend-config "storage_account_name=migrationstfstateazure" \
 -backend-config "container_name=tfstate" \
 -backend-config "key=terraform.tfstate"

# plan
terraform plan -out main.tfplan

# apply
terraform apply "main.tfplan"
```

### OS Source Kafka deployment

(todo: migrate to cp-ansible)

```bash
# log into your jumphost with ssh access to the VMs
ssh azureuser@20.224.156.254 -i ~/.ssh/migrations-SSHKey

# Install Azure.Azcollection inventory plugin
ansible-galaxy collection install azure.azcollection:1.11.0 && \
pip install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt

# declare private key location
export ANSIBLE_KEY_FILE="~/.ssh/migrations-SSHKey"

# clone 
git clone git@github.com:vcosqui/ansible-os-kafka-deployment.git
cd ansible-os-kafka-deployment

# setup inventory hosts file
[all:vars]
zookeeper_servers_use_inventory_hostname = true

[kafka_nodes:vars]
kafka_zookeeper_connect=zookeeper1:2181,zookeeper2:2181,zookeeper3:2181
kafka_auto_create_topics_enable=true

[kafka_nodes]
kafka1 kafka_broker_id=1 ansible_host=10.1.0.7
kafka2 kafka_broker_id=2 ansible_host=10.1.0.5
kafka3 kafka_broker_id=3 ansible_host=10.1.0.6

[zookeeper_nodes]
zookeeper1 zookeeper_id=1 ansible_host=10.1.0.9
zookeeper2 zookeeper_id=2 ansible_host=10.1.0.8
zookeeper3 zookeeper_id=3 ansible_host=10.1.0.4

# test you host reachability
ansible all -m ping -i hosts

# install zookeeper and OS kafka
ansible-galaxy install sleighzy.zookeeper
ansible-playbook zookeeper.yaml -i hosts
ansible-galaxy install sleighzy.kafka
ansible-playbook kafka.yaml -i hosts

# test producer
echo "test message" |  kafkacat -b kafka1 -t test -P
# test consumer
kafkacat -b kafka1 -t test
```

### Horton Schema Registry deployment

```bash
# git clone
git clone git@github.com:vcosqui/ansible-horton-sr-deployment.git
cd ansible-horton-sr-deployment

# set ansible ssh key
export ANSIBLE_KEY_FILE=/home/azureuser/.ssh/migrations-SSHKey

# ping hosts
make ping-hosts
# install SR
make install 
# test SR
make test
```

## Destination cluster deployment

### Set environment variables

```bash
export TF_VAR_pub_key_path="~/.ssh/migrations-SSHKey.pub"
export TF_VAR_resource_group_name="migrations"
export TF_VAR_vnet_name="migrations-vnet"
export TF_VAR_subnet_name="migrations-destination-subnet"
export TF_VAR_subnet_addres_prefix="10.1.1.0/24"
export TF_VAR_user_name="kafka"

export TF_VAR_zk_vm_type="Standard_B2ms"
export TF_VAR_zk_data_disk_size=40
export TF_VAR_zk_data_disk_count=1
export TF_VAR_zk_log_disk_size=80
export TF_VAR_broker_vm_type="Standard_B2ms"
export TF_VAR_broker_log_disk_size=80
export TF_VAR_broker_log_disk_count=1
export TF_VAR_sr_count=1
export TF_VAR_connect_count=1
export TF_VAR_ksql_count=1
export TF_VAR_c3_count=1
```

### Prepare and run deployment

```bash
# clone terraform project
git clone git@github.com:ogomezso/tf-cp-cloud-infra-provision.git
cd tf-cp-cloud-infra-provision/azure

# init
terraform init -backend-config "resource_group_name=migrations" \
 -backend-config "storage_account_name=migrationstfstateazure" \
 -backend-config "container_name=tfstatedestination" \
 -backend-config "key=terraform.tfstate"

# plan
terraform plan -out main.tfplan

# apply
terraform apply "main.tfplan"
```

### Confluent Platform deployment

```bash
# log into your jumphost with ssh access to the VMs
ssh azureuser@20.224.156.254 -i ~/.ssh/migrations-SSHKey

# clone github repo
git clone git@github.com:vcosqui/ansible-cp-deployment.git 
cd ansible-cp-deployment

# install confluent platform via ansible-galaxy
ansible-galaxy collection install confluent.platform

# test you host reachability
ansible -i hosts.yml all -m ping

# validate hosts
ansible-playbook -i hosts.yml confluent.platform.validate_hosts

# install confluent platform
ansible-playbook -i hosts.yml confluent.platform.all

```

## Source resources (schemas, topics, data..)

```bash
# orders schema
cat orders.schema
{"schema": "{ \"type\": \"record\", \"name\": \"orders\", \"fields\": [{\"name\": \"ordertime\", \"type\": \"long\"}, {\"name\": \"orderid\", \"type\": \"int\"}, {\"name\": \"itemid\", \"type\": \"string\"}, {\"name\": \"orderunits\", \"type\": \"double\"}, {\"name\": \"address\", \"type\": {\"fields\": [{\"name\": \"city\", \"type\": \"string\"}, {\"name\": \"state\", \"type\": \"string\"}, {\"name\": \"zipcode\", \"type\": \"long\"}], \"name\": \"address\", \"type\": \"record\"}}] }" }
export SR=$(cat orders.schema)
curl -s -X POST -H "Content-Type: application/json" --data "$SR" http://migrations-migrations-source-subnet-sr-0:9090/api/v1/confluent/subjects/test3-value/versions
{"id":1}

```

## Cluster linking

### Temporary workaround

While broker hosts are not available in public DNS servers we have to temporally modify the destination brokers to be able to resolve the advertised hosts of the source brokers

```bash
# for each destination broker
ssh kafka@migrations-migrations-destination-subnet-broker-2 -i ~/.ssh/migrations-SSHKey
# append to hosts file
sudo tee -a /etc/hosts > /dev/null <<'EOF'
10.1.0.5        kafka1
10.1.0.10       kafka2
10.1.0.8        kafka3
EOF
```

### Create cluster link

```bash
# include all consumer group offsets in the link
cat << EOF > test-link-consumer-group.json
{"groupFilters": [{"name": "*","patternType": "LITERAL","filterType": "INCLUDE"}]}
EOF

# configure the link source
cat << EOF > test-link.properties
bootstrap.servers=kafka1:9092
consumer.offset.sync.enable=true
consumer.offset.sync.ms=5000
EOF

# create the link
./confluent-7.4.0/bin/kafka-cluster-links \
--bootstrap-server migrations-migrations-destination-subnet-broker-2:9092 \
-create --link test-link \
--config-file ./test-link.properties \
--consumer-group-filters-json-file ./test-link-consumer-group.json

# list links
./confluent-7.4.0/bin/kafka-cluster-links \
--bootstrap-server migrations-migrations-destination-subnet-broker-2:9092 \
-list
Link name: 'test-link', link ID: 'sTN9wWt5RMqSKLNuqOS5hg', remote cluster ID: 'IggAznuXSE6TONUPl4stUQ', local cluster ID: 'PaT_OOzxRrW4emipXhNpAw', remote cluster available: 'true', link state: 'ACTIVE'

# check link status
./confluent-7.4.0/bin/kafka-cluster-links \
--bootstrap-server migrations-migrations-destination-subnet-broker-2:9092 \
-describe --link test-link
Link name: 'test-link', link ID: 'sTN9wWt5RMqSKLNuqOS5hg', remote cluster ID: 'IggAznuXSE6TONUPl4stUQ', local cluster ID: 'PaT_OOzxRrW4emipXhNpAw', link mode: 'DESTINATION', connection mode: 'OUTBOUND', link state: 'ACTIVE', link coordinator id: '0', link coordinator host: 'migrations-migrations-destination-subnet-broker-0', topics: []
Configs: consumer.offset.sync.ms=5000,bootstrap.servers=kafka1:9092,consumer.offset.sync.enable=true,consumer.offset.group.filters={"groupFilters": [{"name": "*","patternType": "LITERAL","filterType": "INCLUDE"}]},local.listener.name=INTERNAL
```