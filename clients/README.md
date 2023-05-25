# Clients

For DEMO purpose we gonna provision a managed Kubernetes cluster you can go to the cloud provider of your choice folder and use the terraform scripts inside to get a provision run book.

> Note: Be aware that you will need dns resolution for all 3 brokers

## Client Deployment

For sake of simplicity we gonna use [reloader](https://github.com/stakater/Reloader) for the configuration and rolling updates management.

To install it (on default namespace):

```bash
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml
```

You will need to create a `clients namespace` by running:

```bash
kubectl create namespace clients
```

Deploy the config maps (we gonna start with the src cluster) running (from project root folder):

```bash
kubectl apply -f clients/java/java-producer-src-configmap.yaml
kubectl apply -f clients/java/java.consumer-src-configmap.yaml
```

Deploy java applications:

```bash
kubectl apply -f clients/java/java-producer.yaml
kubectl apply -f clients/java/java-consumer.yaml
```

### Execution

For this simple scenario we gonna have a simple ´java producer pod´ that produce a simple chuck fact via rest endopint `/chuck-says`exposed by a load balancer through the `8080 port` and forward it to a `chuck-topic` on the configured cluster

To produce msgs just get the public IP of your svc with:

```bash
kubectl get svc -n clients
```

and post a msgs via curl:

```bash
curl -X POST http://<svc public ip>:8080/chuck-says
```

The consumer will start to consume it, you can see the msgs being consumer by:

get the pod name:

```bash
kubectl get pods -n clients | grep java-consumer
````

inspect kubernetes logs:

```bash
kubectl logs -w <pod-name>
```

you can also produce messages on a bulk mode using `gatling`for this just go to `clients/perftest` folder configure your test scenario with your `svc base endpoint` the number of request you want to perform (msgs to the topic at the end of the day) and the number of concurrent users you want to simulate, the execute from perftest folder:

```bash
mvn gatling:test
```
