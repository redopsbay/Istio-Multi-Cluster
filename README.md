# Istio Multi Cluster 🧱 #

![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)



| Platform               | Version |
| ---------------------- | ------- |
| Istio                  | 1.13.2  |
| Terraform              | v1.1.9  |
| Terraform AWS Provider | 4.0.0   |
| Kubernetes Version     | 1.21    |
| Helm                   | 3       |

🛡️ Introduction
================
Setup Istio service mesh with Multi-Primary on Different networks


## Provisioning your infrastructure ##

Creating a terraform workspace
```
terraform workspace new istio-service-mesh
```

Planning Phase
```
terraform init
terraform workspace select istio-service-mesh
terraform fmt
terraform validate
terraform plan -out='plan.out'
```

Provisioning
```
terraform apply 'plan.out'
```

✅ Installing Istio inside your cluster
======================================

Installing your Istio on your provisioned clusters via Helm Charts

Cluster1
==========
Adding Istio helm repositories
```
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

Adding metrics-server helm repository
```
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
```

🔒Making sure HPA would work. Install metrics-server on both clusters.
```
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system
```

Installing IstioBase chart
```
helm upgrade --install istio-base istio/base \
    --create-namespace -n istio-system \
    --version 1.13.2 --wait
```

Installing Istio-CP
```
helm upgrade --install istiod istio/istiod -n istio-system --create-namespace \
    --wait --version 1.13.2 \
    --set global.meshID="cluster1" \
    --set global.multiCluster.clusterName="cluster1" \
    --set global.network="cluster1" 
```

Install Istio-ingress gateway

***📓 In my case. I want to use ALB instead of Classic or NLB***
```
kubectl create namespace istio-ingress
kubectl label namespace istio-ingress istio-injection=enabled

helm upgrade --install istio-ingressgateway istio/gateway \
     -n istio-ingress --create-namespace \
     --version 1.13.2 --set service.type="NodePort"
``` 


Cluster2
=========
Adding Istio helm repositories
```
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

Adding metrics-server helm repository
```
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
```

🔒Making sure HPA would work. Install `metrics-server` on both clusters.
```
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system
```

Installing IstioBase chart
```
helm upgrade --install istio-base istio/base \
    --create-namespace -n istio-system \
    --version 1.13.2 --wait
```

Installing Istio-CP
```
helm upgrade --install istiod istio/istiod \
    -n istio-system --create-namespace \
    --wait --version 1.13.2 \
    --set global.meshID="cluster2" \
    --set global.multiCluster.clusterName="cluster2" \
    --set global.network="cluster2"
```

Setup Ingress Controller
==========================

Use this template to create AWS ALB on your cluster and associate it with your `istio-ingressgateway` resource. `Ingress.yaml`
```
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: istio-alb-ingress
  namespace: istio-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/healthcheck-path: /healthz/ready
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/certificate-arn: "<your-certificate-arn>"
    alb.ingress.kubernetes.io/listen-ports: '[{ "HTTP": 80 }, { "HTTPS": 443 }]'
    alb.ingress.kubernetes.io/security-groups: <your-security-group-id>
    alb.ingress.kubernetes.io/scheme: internet-facing
    #alb.ingress.kubernetes.io/target-type: instance
    alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
    alb.ingress.kubernetes.io/tags: Environment=Test,Provisioner=Kubernetes
  labels:
    app:  "Istio"
    ingress: "Istio"
spec:
  rules:
    - http:
        paths:
          - path: /*
            backend:
              serviceName: ssl-redirect
              servicePort: use-annotation
          - path: /healthz/ready
            backend:
              serviceName: istio-ingressgateway
              servicePort: 15021
          - path: /*
            backend:
              serviceName: istio-ingressgateway
              servicePort: 443
```

## 🔐 Remove server details ##

Removing server details is very important specially on production environment. `Envoyfilter.yaml`
```
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  namespace: istio-system
  name: replace-server-name
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
    - applyTo: NETWORK_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.http_connection_manager
      patch:
        operation: MERGE
        value:
          typed_config:
            '@type': type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
            server_name: 'custom server name'
```

## Exposing Services ##

Install additional `ingress-gateway` for both `cluster1` and `cluster2`. Since, earlier. ALB is used. So, the service discovery will fail due to Ingress gateway not directly exposing traffic.

## cluster1 ##

```
helm upgrade --install istio-crossnetworkgateway istio/gateway \
     -n istio-system --create-namespace --version 1.13.2
```

## cluster2 ##

```
helm upgrade --install istio-crossnetworkgateway istio/gateway \
     -n istio-system --create-namespace --version 1.13.2
```

Exposing services for both cluster. 
`expose-cross-network-gateway.yaml`
```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: cross-network-gateway
  namespace: istio-system
spec:
  selector:
    app: istio-crossnetworkgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: AUTO_PASSTHROUGH
      hosts:
        - "*.local"
```

Apply the gateway config.
```
kubectl apply -f expose-cross-network-gateway.yaml
```

Enable endpoint discovery 
==========================

This section will provide endpoint discovery. So both cluster's can discover different endpoints.

Type the command on cluster1:
```
istioctl x create-remote-secret --name=cluster1 > cluster2-secret.yaml
```

On cluster2, Type the command:
```
istioctl x create-remote-secret --name=cluster2 > cluster1-secret.yaml
```

Applying service discovery 
===========================

On cluster1. Type the command:
```
kubectl apply -f cluster1-secret.yaml
```

On cluster2. Type the command:
```
kubectl apply -f cluster2-secret.yaml
```

Verify Trust Configuration
============================

Verify if trust configuration is properly plugged-in.
```
diff \
   <(export KUBECONFIG=$(pwd)/kubeconfig_cluster1.yaml && kubectl -n istio-system get secret cacerts -ojsonpath='{.data.root-cert\.pem}') \
   <(export KUBECONFIG=$(pwd)/kubeconfig_cluster2.yaml && kubectl -n istio-system get secret cacerts -ojsonpath='{.data.root-cert\.pem}')
```

If there's no certificate found on both clusters. You can generate a self-signed root CA certificate.

## Generating root CA cert ##

```
cd istio-tool
mkdir -p certs
pushd certs
make -f ../Makefile.selfsigned.mk root-ca
```

## Generate Cert for cluster1 ##

```
make -f ../Makefile.selfsigned.mk cluster1-cacerts
```

## Generate cert for cluster2 ##

```
make -f ../tools/certs/Makefile.selfsigned.mk cluster2-cacerts
```

## Creating CA Cert secret ##

From cluster1, Apply the command below:
```
kubectl create secret generic cacerts -n istio-system \
      --from-file=cluster1/ca-cert.pem \
      --from-file=cluster1/ca-key.pem \
      --from-file=cluster1/root-cert.pem \
      --from-file=cluster1/cert-chain.pem
```

From cluster2, Apply the command below:
```
kubectl create secret generic cacerts -n istio-system \
      --from-file=cluster2/ca-cert.pem \
      --from-file=cluster2/ca-key.pem \
      --from-file=cluster2/root-cert.pem \
      --from-file=cluster2/cert-chain.pem
```

Cross Cluster Verification
===========================

To verify if the traffic is distributed on both cluster's. You can try the [MetaPod](https://github.com/redopsbay/MetaPod) sample application.

From `cluster1`, Deploy the application by using the sample manifest.

```
kubectl apply -f manifests/cluster1-deployment.yaml
```

From `cluster2`, Deploy the application by using the sample manifest.

```
kubectl apply -f manifests/cluster2-deployment.yaml
```

Reference 💡
==========
- [MetaPod](https://github.com/redopsbay/MetaPod)
- [Istio Documentation](https://istio.io/latest/docs)
- [Plugin CA Certs](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/)
- [Install Multi-Primary on different networks](https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/)
- [Troubleshooting Multicluster](https://istio.io/latest/docs/ops/diagnostic-tools/multicluster/)