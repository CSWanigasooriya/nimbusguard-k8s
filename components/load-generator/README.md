# Load Generator Kubernetes Manifests

This component provides different ways to run load tests against your consumer service in Kubernetes.

## 🎯 **Recommended Approach: On-Demand Jobs**

### Quick Test
```bash
# Build and push the image first
docker build -t nimbusguard-generator src/generator/

# Run a heavy load test to trigger KEDA scaling
kubectl apply -f kubernetes-manifests/components/load-generator/job-heavy.yaml

# Watch the job and scaling (use separate terminals)
# Terminal 1: kubectl get jobs,pods -l load-test=heavy -w
# Terminal 2: kubectl get pods -n nimbusguard -l app.kubernetes.io/name=consumer -w
```

### Sustained Load Test
```bash
# Run a long-term load test (60 seconds per request)
kubectl apply -f kubernetes-manifests/components/load-generator/job-sustained.yaml

# Monitor progress
kubectl logs -f job/load-test-sustained
```

## 📋 **Available Job Types**

| Job File | Test Type | Duration | Processing Mode | Purpose |
|----------|-----------|----------|-----------------|---------|
| `job-heavy.yaml` | Heavy load | ~10 min | **Async** | **Trigger immediate scaling** |
| `job-sustained.yaml` | Sustained load | ~30 min | **Async** | **Test scale-up/down cycle** |
| `job-medium.yaml` | Medium load | ~8 min | **Async** | **Realistic moderate load** |
| `job-light.yaml` | Light load | ~5 min | **Async** | **Baseline performance** |
| `job-burst.yaml` | Burst load | ~5 min | **Async** | **High concurrency spikes** |
| `job-memory-stress.yaml` | Memory stress | ~10 min | **Async** | **Memory-based scaling** |
| `job-cpu-stress.yaml` | CPU stress | ~10 min | **Sync** | **CPU-intensive blocking tasks** |

### 🔄 **Async vs Sync Processing**

- **Async Mode (Default)**: Requests return immediately while processing happens in background
  - ✅ **Realistic**: Mirrors real-world microservice patterns
  - ✅ **High Throughput**: Can handle many concurrent requests
  - ✅ **Better Scaling**: Shows how services handle request bursts
  - ✅ **Non-blocking**: Consumer remains responsive during load

- **Sync Mode**: Requests block until processing completes
  - 🔍 **Testing**: Useful for testing resource limits under blocking load
  - ⚠️ **Lower Throughput**: Limited by processing time
  - ⚠️ **Less Realistic**: Most modern services use async patterns

### ⚖️ **KEDA Scaling Triggers**

The system uses **proven scaling triggers** based on FastAPI instrumentator metrics:

| Trigger Type | Metric | Threshold | Purpose |
|-------------|--------|-----------|---------|
| **HTTP Load** | Request rate | > 5 req/sec | Scale for traffic spikes |
| **Latency** | Response time | > 2 seconds | Scale when service slows down |
| **GC Pressure** | Python GC rate | > 0.5/sec | Scale for memory pressure |

This **application-focused scaling** ensures the system responds to:
- 🚀 **Traffic surges** (HTTP request rate)
- 🐌 **Performance degradation** (HTTP latency)  
- 🧠 **Memory pressure** (Python garbage collection)

**Note**: These metrics are provided by `prometheus_fastapi_instrumentator` and are **confirmed working** in the current setup. Additional CPU/memory metrics can be added when proper process-level monitoring is configured.

## 🔧 **Usage in Your Overlays**

### Add to Development Environment
```yaml
# kubernetes-manifests/overlays/development/kustomization.yaml
components:
  - ../../components/consumer
  - ../../components/monitoring
  - ../../components/keda
  - ../../components/load-generator  # Add this
```

### Enable Specific Tests
Edit `kubernetes-manifests/components/load-generator/kustomization.yaml`:
```yaml
resources:
  - job-heavy.yaml        # Uncomment to deploy
  # - job-sustained.yaml  # Uncomment if needed
```

## 🚀 **Complete Testing Workflow**

### 1. Build and Deploy
```bash
# Build the generator image
docker build -t nimbusguard-generator src/generator/

# Deploy everything including load generator jobs
make dev
```

### 2. Run Load Test
```bash
# Apply a specific job
kubectl apply -f kubernetes-manifests/components/load-generator/job-heavy.yaml

# Or create one-off job
kubectl create job load-test-now --image=nimbusguard-generator:latest -- \
  --url=http://consumer:8000 --test=heavy --monitor
```

### 3. Monitor Results
```bash
# Watch job progress
kubectl logs -f job/load-test-heavy

# Watch KEDA scaling with k9s
k9s -n nimbusguard
```

### 4. Cleanup
```bash
# Remove completed jobs
kubectl delete jobs -l component=load-generator

# Or delete specific job
kubectl delete job load-test-heavy
```

## 🎛️ **Customization**

### Create Custom Load Test
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test-custom
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: load-generator
        image: nimbusguard-generator:latest
        args:
        - --url=http://consumer:8000
        - --test=cpu_stress      # or memory_stress, burst, etc.
        - --monitor
        - --cleanup
```

### Run Multiple Concurrent Tests
```bash
# Start multiple jobs for stress testing
kubectl apply -f job-heavy.yaml
kubectl apply -f job-sustained.yaml
kubectl create job burst-test --image=nimbusguard-generator:latest -- \
  --url=http://consumer:8000 --test=burst --monitor
```

## 🔍 **Monitoring Integration**

Load test jobs automatically integrate with your monitoring:

- **Prometheus**: HTTP request metrics from load tests
- **Grafana**: View load patterns and scaling behavior  
- **Tempo**: Trace individual requests through the system
- **Loki**: Aggregate logs from load generation

## ⚠️ **Important Notes**

1. **Image Availability**: Make sure `nimbusguard-generator:latest` is built and available
2. **Service Dependencies**: Jobs include init containers that wait for the consumer service to be ready
3. **Resource Limits**: Jobs have modest resource requests to not interfere with scaling
4. **Active Deadline**: Jobs have timeouts to prevent runaway processes
5. **Network Access**: Jobs use service names (http://consumer:8000) - no port forwarding needed
6. **Cleanup**: Consider setting up automatic job cleanup with TTL or manually clean completed jobs 