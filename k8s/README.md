# Lakehouse Platform — Kubernetes

Manifests Kubernetes para o Lakehouse Platform, organizados por domínio.

## Estrutura

```
k8s/
├── namespaces/
│   └── lakehouse-ns.yaml           # Namespace lakehouse
├── streaming/
│   ├── kafka-configmap.yaml        # Config Kafka KRaft
│   ├── kafka-statefulset.yaml      # Kafka (single broker)
│   ├── kafka-service.yaml          # Service headless + ClusterIP
│   ├── debezium-deployment.yaml    # Kafka Connect + Debezium CDC
│   └── debezium-service.yaml
├── security/
│   ├── keycloak-deployment.yaml    # Keycloak IAM/SSO + Secret + PVC
│   ├── keycloak-service.yaml       # Service + Ingress
│   ├── solr-deployment.yaml        # Solr (audit Ranger) + PVC
│   ├── solr-service.yaml
│   ├── ranger-deployment.yaml      # Ranger Admin + Secret + PVC
│   └── ranger-service.yaml         # Service + Ingress
└── kustomization.yaml              # Kustomize entry point
```

## Pré-requisitos

- Kubernetes 1.25+
- `kubectl` e `kustomize`
- Ingress Controller (NGINX recomendado)
- StorageClass com `ReadWriteOnce` disponível
- PostgreSQL e MinIO rodando (pode ser no mesmo cluster ou externo)

## Deploy

### Tudo de uma vez
```bash
kubectl apply -k platform/k8s/
```

### Somente Streaming (Kafka + Debezium)
```bash
kubectl apply -f platform/k8s/namespaces/lakehouse-ns.yaml
kubectl apply -f platform/k8s/streaming/
```

### Somente Security (Keycloak + Ranger)
```bash
kubectl apply -f platform/k8s/namespaces/lakehouse-ns.yaml
kubectl apply -f platform/k8s/security/
```

## Ranger Admin — Build da imagem customizada

O Ranger Admin requer uma imagem customizada. Antes do deploy K8s:

```bash
# Build
docker build -t myregistry/ranger-admin:2.5.0 platform/ranger/

# Push para o seu registry
docker push myregistry/ranger-admin:2.5.0

# Atualizar a image em ranger-deployment.yaml
# image: myregistry/ranger-admin:2.5.0
```

## Kafka — Verificar topics
```bash
kubectl exec -n lakehouse kafka-0 -- \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## Debezium — Registrar conector CDC
```bash
kubectl exec -n lakehouse deploy/debezium -- \
  curl -sf -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @/tmp/postgres-source.json
```

## Keycloak — Acessar Admin Console
```bash
# Port-forward local
kubectl port-forward -n lakehouse svc/keycloak 8180:8080

# Acesse: http://localhost:8180
# User/Pass: definidos no Secret keycloak-secret
```

## Produção — Secrets

Em produção, **não use stringData hardcoded**. Use:
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault](https://www.vaultproject.io/)
