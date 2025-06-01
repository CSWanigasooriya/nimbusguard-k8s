# NimbusGuard Kubernetes Deployment

This directory contains the Kubernetes manifests and deployment tools for NimbusGuard, organized using Kustomize and following cloud-native best practices.

## 📁 Project Structure

```
k8s-nimbusguard/
├── base/                           # Base Kubernetes resources
│   ├── kustomization.yaml         # Base kustomization configuration
│   ├── namespace.yaml             # Namespace definition
│   ├── deployment.yaml            # Application deployment
│   ├── service.yaml               # Service definition
│   ├── configmap.yaml             # Configuration map
│   ├── hpa.yaml                   # Horizontal Pod Autoscaler
│   └── servicemonitor.yaml        # Prometheus ServiceMonitor
├── overlays/                       # Environment-specific overlays
│   ├── development/               # Development environment
│   │   ├── kustomization.yaml
│   │   ├── deployment-patch.yaml
│   │   ├── configmap-patch.yaml
│   │   ├── ingress.yaml
│   │   └── networkpolicy.yaml
│   ├── staging/                   # Staging environment
│   │   ├── kustomization.yaml
│   │   ├── deployment-patch.yaml
│   │   ├── configmap-patch.yaml
│   │   ├── ingress.yaml
│   │   └── networkpolicy.yaml
│   └── production/                # Production environment
│       ├── kustomization.yaml
│       ├── deployment-patch.yaml
│       ├── configmap-patch.yaml
│       ├── hpa-patch.yaml
│       ├── pdb.yaml
│       ├── ingress.yaml
│       └── networkpolicy.yaml
├── monitoring/                     # Monitoring stack
│   ├── kustomization.yaml
│   ├── servicemonitor.yaml
│   ├── prometheusrule.yaml
│   └── grafana-dashboard.yaml
├── scripts/
│   └── apply-manifests.sh         # Deployment automation script
├── kustomization.yaml             # Root kustomization
└── README.md                      # This file
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.20+)
- `kubectl` configured to access your cluster
- `kustomize` (optional, kubectl has built-in support)

### Deploy to Development

```bash
# Deploy everything to development environment
./scripts/apply-manifests.sh

# Deploy with port forwarding
./scripts/apply-manifests.sh --port-forward

# Deploy only the application
./scripts/apply-manifests.sh --app-only
```

### Deploy to Production

```bash
# Deploy to production (with confirmation prompt)
./scripts/apply-manifests.sh -e production

# Preview what would be deployed (dry run)
./scripts/apply-manifests.sh -e production --dry-run
```

## 🛠️ Deployment Script Usage

The `apply-manifests.sh` script provides a comprehensive deployment tool with the following options:

```bash
Usage: ./scripts/apply-manifests.sh [OPTIONS]

Options:
  -e, --environment ENV   Target environment (development|staging|production) [default: development]
  --app-only             Deploy only the application
  --monitoring-only      Deploy only the monitoring stack
  --no-monitoring        Skip monitoring stack installation
  --no-app              Skip application deployment
  --port-forward        Start port forwarding after deployment
  --port-forward-only   Only start port forwarding (no deployment)
  --cleanup             Only perform cleanup (remove all components)
  --dry-run             Show what would be applied without actually applying
  -v, --verbose         Enable verbose output
  -h, --help            Show this help message

Examples:
  ./scripts/apply-manifests.sh                                    # Deploy to development environment
  ./scripts/apply-manifests.sh -e production                     # Deploy to production environment
  ./scripts/apply-manifests.sh --app-only -e staging            # Deploy only app to staging
  ./scripts/apply-manifests.sh --monitoring-only                # Deploy only monitoring stack
  ./scripts/apply-manifests.sh --port-forward                   # Deploy and start port forwarding
  ./scripts/apply-manifests.sh --cleanup                        # Clean up all resources
  ./scripts/apply-manifests.sh --dry-run -e production          # Preview production deployment
```

## 🌍 Environment Configurations

### Development
- **Replicas**: 1
- **Resources**: Low (100m CPU, 128Mi memory)
- **Debug**: Enabled
- **CORS**: Enabled
- **Rate Limiting**: Disabled
- **Ingress**: `nimbusguard.local` (no TLS)

### Staging
- **Replicas**: 2
- **Resources**: Medium (300m CPU, 256Mi memory)
- **Debug**: Disabled
- **CORS**: Enabled
- **Rate Limiting**: Enabled
- **Ingress**: `nimbusguard-staging.example.com` (TLS enabled)

### Production
- **Replicas**: 3 (min), 20 (max)
- **Resources**: High (500m CPU, 512Mi memory)
- **Debug**: Disabled
- **CORS**: Disabled
- **Rate Limiting**: Enabled
- **Ingress**: `nimbusguard.example.com` (TLS enabled)
- **PDB**: Minimum 2 pods available
- **HPA**: Aggressive scaling

## 📊 Monitoring

The monitoring stack includes:

- **ServiceMonitor**: Prometheus metrics collection
- **PrometheusRule**: Alerting rules for:
  - High CPU usage (>80%)
  - High memory usage (>80%)
  - Pod down alerts
  - High error rate (>10%)
- **Grafana Dashboard**: Application metrics visualization

### Accessing Monitoring

```bash
# Start port forwarding for monitoring services
./scripts/apply-manifests.sh --port-forward-only

# Access services:
# - Grafana: http://localhost:3000 (admin/admin)
# - Prometheus: http://localhost:9090
# - NimbusGuard: http://localhost:8080
```

## 🔧 Manual Deployment with Kustomize

If you prefer to use kustomize directly:

```bash
# Deploy to development
kubectl apply -k overlays/development

# Deploy to production
kubectl apply -k overlays/production

# Deploy monitoring
kubectl apply -k monitoring

# Build and preview (dry run)
kustomize build overlays/production
```

## 🔒 Security Features

### Network Policies
- Ingress: Only from ingress-nginx and monitoring namespaces
- Egress: DNS, HTTPS/HTTP, and database connections only

### Pod Security
- Non-root user (65534)
- Read-only root filesystem
- No privilege escalation
- Dropped capabilities

### Resource Limits
- CPU and memory limits enforced
- Horizontal Pod Autoscaler for scaling
- Pod Disruption Budget for availability

## 🏗️ Architecture Decisions

### Kustomize Structure
- **Base**: Common resources shared across environments
- **Overlays**: Environment-specific configurations
- **Patches**: Strategic merge patches for customization

### Best Practices Implemented
- ✅ Namespace isolation
- ✅ Resource quotas and limits
- ✅ Health checks (liveness/readiness probes)
- ✅ Security contexts
- ✅ Network policies
- ✅ Horizontal Pod Autoscaling
- ✅ Pod Disruption Budgets
- ✅ Monitoring and alerting
- ✅ Configuration management
- ✅ Multi-environment support

## 🔍 Troubleshooting

### Check Deployment Status
```bash
# Application status
kubectl get all -n nimbusguard

# Pod logs
kubectl logs -f deployment/nimbusguard -n nimbusguard

# HPA status
kubectl get hpa -n nimbusguard

# Events
kubectl get events -n nimbusguard --sort-by='.lastTimestamp'
```

### Common Issues

1. **Image Pull Errors**: Ensure the Docker image is built and available
2. **Resource Constraints**: Check if cluster has sufficient resources
3. **Network Policies**: Verify ingress controller and monitoring namespaces are labeled correctly
4. **TLS Issues**: Ensure cert-manager is installed for production/staging

### Cleanup
```bash
# Remove everything
./scripts/apply-manifests.sh --cleanup

# Or manually
kubectl delete namespace nimbusguard
kubectl delete namespace monitoring
```

## 📝 Customization

### Adding New Environments
1. Create a new overlay directory under `overlays/`
2. Add `kustomization.yaml` with base reference
3. Add environment-specific patches
4. Update the deployment script to recognize the new environment

### Modifying Resources
1. Edit base resources for changes across all environments
2. Use patches in overlays for environment-specific changes
3. Test with `--dry-run` before applying

### Adding Monitoring
1. Add new ServiceMonitors to `monitoring/`
2. Update PrometheusRules for new alerts
3. Add Grafana dashboards as ConfigMaps

## 🤝 Contributing

1. Follow the existing structure and naming conventions
2. Test changes with `--dry-run` first
3. Ensure all environments are tested
4. Update documentation for any new features

## 📚 References

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/) 