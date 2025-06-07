# NimbusGuard Kubernetes Manifests

This directory contains all Kubernetes manifests for deploying the NimbusGuard AI-powered autoscaling platform.

## Quick Deploy

### Prerequisites

- Kubernetes cluster (local or cloud)
- kubectl configured and connected
- OpenAI API key (for AI agents)

### 1. Set OpenAI API Key

```bash
export OPENAI_API_KEY="sk-your-openai-api-key-here"
```

### 2. Deploy Complete Platform

```bash
# Deploy everything
kubectl apply -k kubernetes-manifests/

# Or use the deployment script
./scripts/operations/deploy-nimbusguard.sh
```

### 3. Access Services

```bash
# Start port forwarding
./scripts/utilities/port-forward.sh

# Access URLs:
# - Grafana: http://localhost:3000 (admin/nimbusguard)
# - Prometheus: http://localhost:9090
# - Consumer Workload: http://localhost:8080
# - Load Generator: http://localhost:8081
# - LangGraph Operator: http://localhost:8082
```

## Component Deployment

### Core Platform Only

```bash
kubectl apply -k kubernetes-manifests/base/
```

### Observability Stack

```bash
kubectl apply -k kubernetes-manifests/components/observability/
```

### KEDA Event-Driven Scaling

```bash
kubectl apply -k kubernetes-manifests/components/keda/
```

## Directory Structure

```
kubernetes-manifests/
├── base/                           # Core NimbusGuard components
│   ├── kustomization.yaml
│   ├── namespace.yaml              # nimbusguard namespace
│   ├── crds.yaml                   # Custom Resource Definitions
│   ├── rbac.yaml                   # RBAC permissions
│   ├── configmaps.yaml             # Configuration and prompts
│   ├── kafka.yaml                  # Kafka + Zookeeper
│   ├── consumer-workload.yaml      # Workload generator + consumer
│   ├── load-generator.yaml         # Load generation service
│   └── langgraph-operator.yaml     # AI operator
├── components/
│   ├── observability/              # Monitoring stack
│   │   ├── kustomization.yaml
│   │   ├── prometheus.yaml
│   │   └── grafana.yaml
│   └── keda/                       # Event-driven scaling
│       ├── kustomization.yaml
│       ├── keda-operator.yaml
│       └── scaled-objects.yaml
└── kustomization.yaml              # Main deployment
```

## Configuration

### Custom Resources

The platform defines two custom resources:

#### ScalingPolicy
```yaml
apiVersion: nimbusguard.io/v1
kind: ScalingPolicy
metadata:
  name: my-scaling-policy
spec:
  target:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  scaling:
    minReplicas: 1
    maxReplicas: 20
    cooldownPeriod: 300
  aiConfig:
    qLearning:
      learningRate: 0.1
      discountFactor: 0.95
  metrics:
    cpu:
      targetUtilization: 70
    memory:
      targetUtilization: 80
```

#### AIModel
```yaml
apiVersion: nimbusguard.io/v1
kind: AIModel
metadata:
  name: my-model
spec:
  modelType: q-learning
  version: "1.0"
  training:
    dataSource: prometheus
    schedule: "0 */6 * * *"
```

### Environment Variables

Key environment variables for configuration:

```bash
# OpenAI Configuration
OPENAI_API_KEY="sk-your-key"

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS="kafka:9092"

# Prometheus Configuration  
PROMETHEUS_URL="http://prometheus-server:9090"

# Logging
LOG_LEVEL="INFO"
```

## Testing the Platform

### 1. Generate CPU Load

```bash
curl -X POST "http://localhost:8080/workload/cpu?intensity=80&duration=300"
```

### 2. Generate Memory Load

```bash
curl -X POST "http://localhost:8080/workload/memory?intensity=70&duration=300"
```

### 3. Trigger Scaling Event

```bash
curl -X POST http://localhost:8080/events/trigger \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "high_cpu_usage",
    "service": "consumer-workload", 
    "value": 90
  }'
```

### 4. Generate Load Pattern

```bash
curl -X POST http://localhost:8081/load/generate \
  -H "Content-Type: application/json" \
  -d '{
    "pattern": "spike",
    "duration": 300,
    "target": "http"
  }'
```

## Monitoring

### View Scaling Decisions

```bash
kubectl get scalingpolicies -n nimbusguard
kubectl describe scalingpolicy consumer-workload-policy -n nimbusguard
```

### View AI Models

```bash
kubectl get aimodels -n nimbusguard
```

### View Pods and Resources

```bash
kubectl get pods -n nimbusguard
kubectl get hpa -n nimbusguard
kubectl get scaledobjects -n nimbusguard
```

### View Logs

```bash
# LangGraph Operator logs
kubectl logs -f deployment/langgraph-operator -n nimbusguard

# Consumer Workload logs
kubectl logs -f deployment/consumer-workload -n nimbusguard

# Load Generator logs
kubectl logs -f deployment/load-generator -n nimbusguard
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n nimbusguard
kubectl describe pod <pod-name> -n nimbusguard
```

### Check Events

```bash
kubectl get events -n nimbusguard --sort-by='.lastTimestamp'
```

### Check OpenAI API Key

```bash
kubectl get secret openai-api-key -n nimbusguard -o yaml
```

### Restart Operator

```bash
kubectl rollout restart deployment/langgraph-operator -n nimbusguard
```

## Cleanup

### Remove Everything

```bash
kubectl delete -k kubernetes-manifests/
kubectl delete namespace nimbusguard
kubectl delete namespace keda
```

### Remove Specific Components

```bash
# Remove KEDA
kubectl delete -k kubernetes-manifests/components/keda/

# Remove Observability
kubectl delete -k kubernetes-manifests/components/observability/

# Remove Core Platform
kubectl delete -k kubernetes-manifests/base/
```

## Security Considerations

1. **OpenAI API Key**: Store securely, rotate regularly
2. **RBAC**: Review permissions for production deployment
3. **Network Policies**: Add network segmentation
4. **Pod Security**: Enable Pod Security Standards
5. **Secrets Management**: Use external secret management in production

## Production Deployment

For production deployment, consider:

1. **Resource Limits**: Update resource requests/limits
2. **Persistent Storage**: Add persistent volumes for models
3. **High Availability**: Deploy multiple replicas
4. **Monitoring**: Add alerting and SLA monitoring
5. **Backup**: Implement model and configuration backup
6. **Security**: Enable pod security policies and network policies 