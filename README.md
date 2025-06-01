# NimbusGuard Kubernetes Configurations

This repository contains Kubernetes configurations for deploying NimbusGuard.

## Structure

- `deployment.yaml`: Main deployment configuration with node affinity and topology spread
- `service.yaml`: Service configuration for exposing the deployment

## Node Requirements

The deployment is configured to:
- Run only on worker nodes (avoiding control-plane nodes)
- Spread pods evenly across available nodes
- Run 2 replicas for high availability

## Deployment

To deploy NimbusGuard on Kubernetes:

1. Ensure your nodes are ready:
```bash
kubectl get nodes
```

2. Build and load the Docker image on your worker nodes:
```bash
docker build -t nimbusguard:latest .
```

3. Apply the configurations:
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

4. Verify the deployment:
```bash
kubectl get deployments
kubectl get pods -o wide  # Shows which nodes pods are scheduled on
kubectl get services
```

## Configuration Details

### Deployment Configuration
- **Replicas**: 2 pods for high availability
- **Node Affinity**: Pods scheduled only on worker nodes
- **Topology Spread**: Pods distributed evenly across nodes
- **Resource Limits**:
  - CPU limit: 2 cores
  - Memory limit: 2GB
  - CPU request: 500m
  - Memory request: 512MB
- **Health check endpoint**: `/health`
- **Service port**: 8000

### Service Configuration
- Type: ClusterIP
- Port: 8000

## Troubleshooting

1. If pods are not scheduling:
```bash
kubectl describe pod <pod-name>
```

2. Check node status:
```bash
kubectl describe node <node-name>
```

3. View pod logs:
```bash
kubectl logs <pod-name>
```

## Notes

- Make sure the Docker image is available on all worker nodes
- The service is configured as ClusterIP by default
- Pods will only schedule on nodes without the control-plane role 