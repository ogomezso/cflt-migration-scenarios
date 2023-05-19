# Open Source Kafka to Confluent Platform Migrations Scenarios

Apache Kafka to CP Migration scenarios runbook


## Azure setup

1. log into azure
```bash
az login
```
2. create resource group ****migrations****
```shell
az group create --location westeurope \
                --name migrations \
                --tags 'owner_email=ogomezsoriano@confluent.io'
```
3. find the account id (for example for a single account present)
```bash
az account list | jq -r '.[0].id'
38a5a77f-80b7-4055-ba05-9ea5f3448234
```
4. set current subscription to match the account id
```bash
az account set --subscription "38a5a77f-80b7-4055-ba05-9ea5f3448234"
```
5. create an identity
```bash
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/38a5a77f-80b7-4055-ba05-9ea5f3448234"
Creating 'Contributor' role assignment under scope '/subscriptions/38a5a77f-80b7-4055-ba05-9ea5f3448234'
The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli
{
  "appId": "*** application id ***",
  "displayName": "azure-cli-display-name",
  "password": "*** password ***",
  "tenant": "*** tenant ***"
}
```
6. set environment matching
* ARM_CLIENT_ID to appId
* ARM_CLIENT_SECRET to pass
* ARM_SUBSCRIPTION_ID to account id
* ARM_TENANT_ID to tenant
```bash
export ARM_CLIENT_ID="*** application id ***"
export ARM_CLIENT_SECRET="*** password ***"
export ARM_SUBSCRIPTION_ID="38a5a77f-80b7-4055-ba05-9ea5f3448234"
export ARM_TENANT_ID="*** tenant ***"
```
7. create ssh key
```bash
az sshkey create --name "migrations-SSHKey" --resource-group "migrations"

No public key is provided. A key pair is being generated for you.
Private key is saved to "~/.ssh/1684491093_1535969".
Public key is saved to "~/.ssh/1684491093_1535969.pub".
{
  "id": "/subscriptions/38a5a77f-80b7-4055-ba05-9ea5f3448234/resourceGroups/MIGRATIONS/providers/Microsoft.Compute/sshPublicKeys/migrations-SSHKey",
  "location": "westeurope",
  "name": "migrations-SSHKey",
  "publicKey": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCe9/j9+wSkFo66iOyhGxkep5fzfpg5awpE1SbC4A6ciWiBhV/WCEAeKVe0yG9U5nr2QVXe8BnUw+TXY5lpxC5imrEuJehWtNC5kXtCSZIFZxmEtTQT1v0UATfietlJL05izZ9wgvUGk1ZWWQ/93yHNffYyvgvfe+7SUbXaNST4Lv2OX1iMafDnby4vx7XdadHRIwALrKLQE0FqPbiGCAbRbPKxRAOVvybBT+R+yWzBAzNrGD6Yf6OvSGqwr3V4Kt/nJ+j3sHl6+j/35isag8bPKFUu9oNzOeNEspzXIxXK01jA57u96sI2kc7MGizeY7rB5i9lIa7392LqLiwd4gtafF2IJCeUIdO3/UEdNaa6ptZElfOnGztiiDnVHOWi0iF1YC+y4plmlTh4YZ+4qWcsdyGCL+opzPqA8hLOZOJjo5KddAr+xYmVvOTsgC0H+h6Ah/1viP2FuRr7PWbvS6eg94c7vrWQJV2jF7Mzd2KzOEelENF7SxRmKjz48lFMVIE= generated-by-azure",
  "resourceGroup": "MIGRATIONS",
  "tags": {
    "owner_email": "ogomezsoriano@confluent.io"
  },
  "type": null
}
```
8. create a network
```bash
az network vnet create \
  --name migrations-vnet \
  --resource-group migrations \
  --address-prefix 10.1.0.0/16
{
  "newVNet": {
    "addressSpace": {
      "addressPrefixes": [
        "10.1.0.0/16"
      ]
    },
    "enableDdosProtection": false,
    "etag": "W/\"f1c584ee-5256-4da6-83bf-1979debb739e\"",
    "id": "/subscriptions/38a5a77f-80b7-4055-ba05-9ea5f3448234/resourceGroups/migrations/providers/Microsoft.Network/virtualNetworks/migrations-vnet",
    "location": "westeurope",
    "name": "migrations-vnet",
    "provisioningState": "Succeeded",
    "resourceGroup": "migrations",
    "resourceGuid": "3bb9246a-efad-4dc9-80c2-3677a7224dc3",
    "subnets": [],
    "tags": {
      "owner_email": "ogomezsoriano@confluent.io"
    },
    "type": "Microsoft.Network/virtualNetworks",
    "virtualNetworkPeerings": []
  }
}
```

## Terraform provisioning

1. setup env
```bash
export TF_VAR_pub_key_path="~/.ssh/1684491093_1535969.pub"
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
2. terraform infra
```bash
git clone git@github.com:ogomezso/tf-cp-cloud-infra-provision.git
cd azure
terraform init
terraform plan -out main.tfplan
terraform apply "main.tfplan"
```