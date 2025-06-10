# NimbusGuard Kubernetes Manifests

This directory contains the Kubernetes manifests for deploying the NimbusGuard operator and its dependencies.

## Directory Structure

```
kubernetes-manifests/
├── base/                    # Base manifests
│   ├── crd.yaml            # Custom Resource Definition
│   ├── operator.yaml       # Operator deployment
│   └── kustomization.yaml  # Base kustomization
├── overlays/               # Environment-specific overlays
│   ├── dev/               # Development environment
│   │   └── kustomization.yaml
│   └── prod/              # Production environment
│       └── kustomization.yaml
└── README.md              # This file
```

## Prerequisites

- Kubernetes cluster (v1.19+)
- kubectl configured to access the cluster
- kustomize (v4.0.0+)
- Prometheus and Tempo installed in the cluster

## Deployment

### 1. Set OpenAI API Key

Before deploying, you need to set your OpenAI API key. You can do this in two ways:

#### Option 1: Using kubectl

First, base64 encode your API key:
```bash
echo -n "your-api-key" | base64
```

Then create the secret using the encoded value:
```bash
# For development
kubectl create secret generic operator-secrets \
  --namespace nimbusguard \
  --from-literal=openai_api_key=$(echo -n "your-api-key" | base64)

# For production
kubectl create secret generic operator-secrets \
  --namespace nimbusguard \
  --from-literal=openai_api_key=$(echo -n "your-api-key" | base64)
```

#### Option 2: Using kustomize

1. First, base64 encode your API key:
```bash
echo -n "your-api-key" | base64
```

2. Edit the `kustomization.yaml` file in the appropriate overlay directory and replace the empty API key with the base64 encoded value:
```yaml
secretGenerator:
- name: operator-secrets
  behavior: merge
  literals:
  - openai_api_key=<base64-encoded-key>
```

### 2. Deploy the Operator

#### Development Environment

```bash
kubectl apply -k kubernetes-manifests/overlays/dev
```

#### Production Environment

```bash
kubectl apply -k kubernetes-manifests/overlays/prod
```

## Configuration

The operator can be configured through the `operator-config` ConfigMap. Available options:

- `prometheus_url`: URL of the Prometheus server
- `tempo_endpoint`: URL of the Tempo server
- `log_level`: Logging level (DEBUG, INFO, WARNING, ERROR)
- `evaluation_interval`: Interval in seconds between scaling evaluations

## Monitoring

The operator exposes metrics on port 8080. You can access them through the `nimbusguard-operator` service.

## Troubleshooting

1. Check operator logs:
```bash
kubectl logs -n nimbusguard-dev deployment/nimbusguard-operator
```

2. Check operator status:
```bash
kubectl get pods -n nimbusguard-dev -l app=nimbusguard-operator
```

3. Check CRD status:
```bash
kubectl get crd intelligentscaling.nimbusguard.io
```

## Cleanup

To remove the operator and its resources:

```bash
# Development
kubectl delete -k kubernetes-manifests/overlays/dev

# Production
kubectl delete -k kubernetes-manifests/overlays/prod
```
