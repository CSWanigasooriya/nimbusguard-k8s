# NimbusGuard Kubernetes Configurations

This repository contains Kubernetes configurations for deploying NimbusGuard.

## Structure

- `deployment.yaml`: Main deployment configuration
- `service.yaml`: Service configuration for exposing the deployment

## Deployment

To deploy NimbusGuard on Kubernetes:

1. Apply the configurations:
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

2. Verify the deployment:
```bash
kubectl get deployments
kubectl get pods
kubectl get services
```

## Configuration Details

- The deployment uses resource limits matching the Docker Compose configuration:
  - CPU limit: 2 cores
  - Memory limit: 2GB
  - CPU request: 500m
  - Memory request: 512MB
- Health check endpoint: `/health`
- Service port: 8000

## Notes

- Make sure to build and push the Docker image before deploying
- The service is configured as ClusterIP by default 