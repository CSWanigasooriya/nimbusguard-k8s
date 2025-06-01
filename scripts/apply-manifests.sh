#!/bin/bash

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
ENVIRONMENT="development"
DEPLOY_MONITORING=true
DEPLOY_APP=true
START_PORT_FORWARDING=true
PORT_FORWARD_ONLY=false
CLEANUP_ONLY=false
STATUS_ONLY=false
DRY_RUN=false
VERBOSE=false

# Function to show usage
show_usage() {
    echo -e "${BLUE}NimbusGuard Kubernetes Deployment Tool${NC}"
    echo -e "${BLUE}Built with Kustomize and Best Practices${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  -e, --environment ENV   Target environment (development|staging|production) [default: development]"
    echo "  --app-only             Deploy only the application"
    echo "  --monitoring-only      Deploy only the monitoring stack"
    echo "  --no-monitoring        Skip monitoring stack installation"
    echo "  --no-app              Skip application deployment"
    echo "  --port-forward        Start port forwarding after deployment"
    echo "  --no-port-forwarding  Skip port forwarding after deployment"
    echo "  --port-forward-only   Only start port forwarding (no deployment)"
    echo "  --status              Show deployment status and exit"
    echo "  --cleanup             Only perform cleanup (remove all components)"
    echo "  --dry-run             Show what would be applied without actually applying"
    echo "  -v, --verbose         Enable verbose output"
    echo "  -h, --help            Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0                                    # Deploy everything and start port forwarding"
    echo "  $0 -e production                     # Deploy to production and start port forwarding"
    echo "  $0 --app-only -e staging            # Deploy only app to staging (no port forwarding)"
    echo "  $0 --monitoring-only                # Deploy only monitoring stack"
    echo "  $0 --no-port-forwarding             # Deploy everything but skip port forwarding"
    echo "  $0 --port-forward-only              # Only start port forwarding (no deployment)"
    echo "  $0 --status                         # Check current deployment status"
    echo "  $0 --cleanup                        # Clean up all resources"
    echo "  $0 --dry-run -e production          # Preview production deployment"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
                echo -e "${RED}Error: Environment must be one of: development, staging, production${NC}"
                exit 1
            fi
            shift 2
            ;;
        --app-only)
            DEPLOY_MONITORING=false
            DEPLOY_APP=true
            shift
            ;;
        --monitoring-only)
            DEPLOY_MONITORING=true
            DEPLOY_APP=false
            shift
            ;;
        --no-monitoring)
            DEPLOY_MONITORING=false
            shift
            ;;
        --no-app)
            DEPLOY_APP=false
            shift
            ;;
        --port-forward)
            START_PORT_FORWARDING=true
            shift
            ;;
        --no-port-forwarding)
            START_PORT_FORWARDING=false
            shift
            ;;
        --port-forward-only)
            PORT_FORWARD_ONLY=true
            shift
            ;;
        --status)
            STATUS_ONLY=true
            shift
            ;;
        --cleanup)
            CLEANUP_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Function to print status
print_status() {
    local message="$1"
    local status="$2"
    
    if [ "$status" = "success" ] || [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $message${NC}"
    elif [ "$status" = "warning" ]; then
        echo -e "${YELLOW}⚠ $message${NC}"
    else
        echo -e "${RED}✗ $message${NC}"
        exit 1
    fi
}

# Function to print verbose output
print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[VERBOSE] $1${NC}"
    fi
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
        exit 1
    fi
    print_verbose "kubectl is available"
}

# Function to check if kustomize is available
check_kustomize() {
    if ! command -v kustomize &> /dev/null; then
        echo -e "${YELLOW}kustomize not found, using kubectl kustomize instead${NC}"
        KUSTOMIZE_CMD="kubectl"
        KUSTOMIZE_SUBCOMMAND="kustomize"
    else
        KUSTOMIZE_CMD="kustomize"
        KUSTOMIZE_SUBCOMMAND="build"
        print_verbose "kustomize is available"
    fi
}

# Function to check if Kubernetes cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Unable to connect to Kubernetes cluster. Please check your cluster connection.${NC}"
        exit 1
    fi
    
    local context=$(kubectl config current-context 2>/dev/null)
    print_verbose "Connected to cluster context: $context"
    
    # Warn if deploying to production
    if [ "$ENVIRONMENT" = "production" ]; then
        echo -e "${YELLOW}⚠ WARNING: You are about to deploy to PRODUCTION environment!${NC}"
        echo -e "${YELLOW}Current context: $context${NC}"
        read -p "Are you sure you want to continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo -e "${YELLOW}Deployment cancelled.${NC}"
            exit 0
        fi
    fi
}

# Function to apply kustomize manifests
apply_kustomize() {
    local overlay_path="$1"
    local description="$2"
    
    if [ ! -d "$overlay_path" ]; then
        echo -e "${RED}Error: Overlay directory not found: $overlay_path${NC}"
        exit 1
    fi
    
    echo -e "\n${YELLOW}Applying $description...${NC}"
    print_verbose "Using overlay: $overlay_path"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY RUN] Would apply:${NC}"
        local build_output
        if build_output=$($KUSTOMIZE_CMD $KUSTOMIZE_SUBCOMMAND "$overlay_path" 2>&1); then
            echo -e "${GREEN}✓ Kustomization builds successfully${NC}"
            if [ "$VERBOSE" = true ]; then
                echo "$build_output"
            fi
        else
            echo -e "${RED}✗ Failed to build kustomization${NC}"
            echo -e "${RED}Error: $build_output${NC}"
            return 1
        fi
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        local dry_run_output
        if dry_run_output=$($KUSTOMIZE_CMD $KUSTOMIZE_SUBCOMMAND "$overlay_path" | kubectl apply -f - --dry-run=server 2>&1); then
            echo -e "${GREEN}✓ Server-side dry run successful${NC}"
        else
            echo -e "${RED}✗ Server-side dry run failed${NC}"
            echo -e "${RED}Error: $dry_run_output${NC}"
            return 1
        fi
    fi
    
    $KUSTOMIZE_CMD $KUSTOMIZE_SUBCOMMAND "$overlay_path" | kubectl apply -f -
    print_status "$description applied successfully" "success"
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace="$1"
    local label_selector="$2"
    local timeout="${3:-300}"
    
    echo -e "${YELLOW}Waiting for pods to be ready in namespace $namespace...${NC}"
    
    if kubectl wait --namespace="$namespace" \
        --for=condition=ready pod \
        --selector="$label_selector" \
        --timeout="${timeout}s" 2>/dev/null; then
        echo -e "${GREEN}✓ Pods are ready${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Pods are not ready within timeout. Current status:${NC}"
        kubectl get pods -n "$namespace"
        return 1
    fi
}

# Function to wait for deployment rollout
wait_for_deployment() {
    local namespace="$1"
    local deployment="$2"
    local timeout="${3:-300s}"
    
    echo -e "${YELLOW}Waiting for $deployment deployment to be ready...${NC}"
    if kubectl rollout status deployment/"$deployment" -n "$namespace" --timeout="$timeout"; then
        print_status "$deployment deployment is ready" "success"
        
        # Also wait for pods to be ready
        wait_for_pods "$namespace" "app=$deployment" "60"
    else
        echo -e "${RED}✗ Deployment $deployment failed to become ready within timeout${NC}"
        echo -e "${YELLOW}Current deployment status:${NC}"
        kubectl get deployment "$deployment" -n "$namespace"
        echo -e "${YELLOW}Pod status:${NC}"
        kubectl get pods -n "$namespace" -l "app=$deployment"
        return 1
    fi
}

# Function to deploy application
deploy_application() {
    local overlay_path="$PROJECT_ROOT/overlays/$ENVIRONMENT"
    
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}  Deploying NimbusGuard Application       ${NC}"
    echo -e "${BLUE}  Environment: $ENVIRONMENT               ${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    apply_kustomize "$overlay_path" "NimbusGuard application ($ENVIRONMENT)"
    
    if [ "$DRY_RUN" = false ]; then
        wait_for_deployment "nimbusguard" "nimbusguard" "300s"
        
        # Check if HPA is working
        echo -e "${YELLOW}Checking HPA status...${NC}"
        kubectl get hpa -n nimbusguard
        
        # Show pod status
        echo -e "${YELLOW}Pod status:${NC}"
        kubectl get pods -n nimbusguard -o wide
    fi
}

# Function to deploy monitoring
deploy_monitoring() {
    local monitoring_path="$PROJECT_ROOT/monitoring"
    
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}  Deploying Monitoring Stack              ${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    # Check if monitoring namespace exists, create if not
    if ! kubectl get namespace monitoring &>/dev/null; then
        echo -e "${YELLOW}Creating monitoring namespace...${NC}"
        kubectl create namespace monitoring
        print_status "Monitoring namespace created" "success"
    fi
    
    # Check if Helm is available for installing Prometheus Operator
    if command -v helm &> /dev/null; then
        echo -e "${YELLOW}Installing Prometheus Operator with Helm...${NC}"
        
        # Add prometheus-community repo if not exists
        if ! helm repo list | grep -q prometheus-community; then
            helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
            helm repo update
        fi
        
        # Install or upgrade kube-prometheus-stack
        if helm list -n monitoring | grep -q prometheus; then
            echo -e "${YELLOW}Upgrading existing Prometheus stack...${NC}"
            helm upgrade prometheus prometheus-community/kube-prometheus-stack \
                --namespace monitoring \
                --set grafana.adminPassword=admin \
                --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
                --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false
        else
            echo -e "${YELLOW}Installing Prometheus stack...${NC}"
            helm install prometheus prometheus-community/kube-prometheus-stack \
                --namespace monitoring \
                --set grafana.adminPassword=admin \
                --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
                --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false
        fi
        
        print_status "Prometheus Operator installed via Helm" "success"
    else
        echo -e "${YELLOW}Helm not found. Installing Prometheus Operator via kubectl...${NC}"
        
        # Install Prometheus Operator via kubectl
        kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/bundle.yaml
        
        # Create a basic Prometheus instance
        cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
  namespace: monitoring
spec:
  serviceAccountName: prometheus
  serviceMonitorSelector: {}
  ruleSelector: {}
  resources:
    requests:
      memory: 400Mi
  retention: 24h
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF
        
        print_status "Prometheus Operator installed via kubectl" "success"
    fi
    
    if [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}Waiting for monitoring CRDs to be ready...${NC}"
        
        # Wait for ServiceMonitor CRD to be available
        local timeout=120
        local counter=0
        while ! kubectl get crd servicemonitors.monitoring.coreos.com &>/dev/null; do
            if [ $counter -ge $timeout ]; then
                echo -e "${YELLOW}⚠ ServiceMonitor CRD not ready after ${timeout}s, continuing anyway...${NC}"
                break
            fi
            sleep 2
            counter=$((counter + 2))
            echo -n "."
        done
        echo ""
        
        if kubectl get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
            echo -e "${GREEN}✓ Monitoring CRDs are ready${NC}"
            
            # Now apply our custom monitoring resources
            echo -e "${YELLOW}Applying custom monitoring resources...${NC}"
            apply_kustomize "$monitoring_path" "Custom monitoring resources"
        else
            echo -e "${RED}✗ Failed to install monitoring CRDs${NC}"
            return 1
        fi
        
        echo -e "${YELLOW}Monitoring resources deployed. Check status with:${NC}"
        echo -e "  kubectl get all -n monitoring"
    fi
}

# Function to start port forwarding
start_port_forwarding() {
    echo -e "\n${YELLOW}Starting port forwarding services...${NC}"
    
    # Kill any existing port forwarding processes
    echo -e "${YELLOW}Stopping any existing port forwarding...${NC}"
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Array to track background processes
    declare -a PORT_FORWARD_PIDS=()
    declare -a USED_PORTS=()
    
    # Function to check if port is available
    is_port_available() {
        local port=$1
        ! netstat -tuln 2>/dev/null | grep -q ":$port " && ! printf "%s\n" "${USED_PORTS[@]}" | grep -q "^$port$"
    }
    
    # Function to find next available port
    find_available_port() {
        local base_port=$1
        local port=$base_port
        while ! is_port_available $port; do
            port=$((port + 1))
        done
        USED_PORTS+=($port)
        echo $port
    }
    
    # Check for NimbusGuard service and pods
    if kubectl get service nimbusguard-service -n nimbusguard &>/dev/null; then
        echo -e "${YELLOW}Checking NimbusGuard pod status...${NC}"
        
        # Wait for at least one pod to be ready
        local ready_pods=$(kubectl get pods -n nimbusguard -l app=nimbusguard --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        
        if [ -n "$ready_pods" ]; then
            local app_port=$(find_available_port 8080)
            echo -e "${YELLOW}Starting NimbusGuard service port forwarding ($app_port -> 80)...${NC}"
            kubectl port-forward -n nimbusguard service/nimbusguard-service $app_port:80 &
            PORT_FORWARD_PIDS+=($!)
            echo -e "${GREEN}✓ NimbusGuard API available at http://localhost:$app_port${NC}"
        else
            echo -e "${YELLOW}⚠ NimbusGuard pods are not ready yet. Checking status:${NC}"
            kubectl get pods -n nimbusguard -l app=nimbusguard 2>/dev/null || echo -e "${YELLOW}  No pods found${NC}"
            echo -e "${YELLOW}  Skipping NimbusGuard port forwarding${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ NimbusGuard service not found. Skipping port forwarding.${NC}"
    fi
    
    # Check for Monitoring services (kube-prometheus-stack first)
    if kubectl get namespace monitoring &>/dev/null; then
        # Prometheus
        if kubectl get service prometheus-kube-prometheus-prometheus -n monitoring &>/dev/null; then
            local prom_port=$(find_available_port 9090)
            echo -e "${YELLOW}Starting Prometheus port forwarding ($prom_port -> 9090)...${NC}"
            kubectl port-forward -n monitoring service/prometheus-kube-prometheus-prometheus $prom_port:9090 &
            PORT_FORWARD_PIDS+=($!)
            echo -e "${GREEN}✓ Prometheus available at http://localhost:$prom_port${NC}"
        fi
        
        # Grafana
        if kubectl get service prometheus-grafana -n monitoring &>/dev/null; then
            local grafana_port=$(find_available_port 3000)
            echo -e "${YELLOW}Starting Grafana port forwarding ($grafana_port -> 80)...${NC}"
            kubectl port-forward -n monitoring service/prometheus-grafana $grafana_port:80 &
            PORT_FORWARD_PIDS+=($!)
            echo -e "${GREEN}✓ Grafana available at http://localhost:$grafana_port${NC}"
            echo -e "${CYAN}  Default credentials: admin/admin${NC}"
        fi
        
        # Alertmanager
        if kubectl get service prometheus-kube-prometheus-alertmanager -n monitoring &>/dev/null; then
            local alert_port=$(find_available_port 9093)
            echo -e "${YELLOW}Starting Alertmanager port forwarding ($alert_port -> 9093)...${NC}"
            kubectl port-forward -n monitoring service/prometheus-kube-prometheus-alertmanager $alert_port:9093 &
            PORT_FORWARD_PIDS+=($!)
            echo -e "${GREEN}✓ Alertmanager available at http://localhost:$alert_port${NC}"
        fi
        
        # Fallback: Check for other Grafana/Prometheus services with generic labels
        if [ ${#PORT_FORWARD_PIDS[@]} -eq 0 ] || ! kubectl get service prometheus-grafana -n monitoring &>/dev/null; then
            local grafana_services=$(kubectl get service -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | wc -l)
            
            if [ "$grafana_services" -gt 0 ]; then
                local grafana_service=$(kubectl get service -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                
                if [ -n "$grafana_service" ]; then
                    local grafana_port=$(find_available_port 3000)
                    echo -e "${YELLOW}Starting Grafana port forwarding ($grafana_port -> 80)...${NC}"
                    kubectl port-forward -n monitoring service/"$grafana_service" $grafana_port:80 &
                    PORT_FORWARD_PIDS+=($!)
                    echo -e "${GREEN}✓ Grafana available at http://localhost:$grafana_port${NC}"
                    echo -e "${CYAN}  Default credentials: admin/admin${NC}"
                fi
            fi
            
            local prometheus_services=$(kubectl get service -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | wc -l)
            
            if [ "$prometheus_services" -gt 0 ]; then
                local prometheus_service=$(kubectl get service -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                
                if [ -n "$prometheus_service" ]; then
                    local prom_port=$(find_available_port 9090)
                    echo -e "${YELLOW}Starting Prometheus port forwarding ($prom_port -> 9090)...${NC}"
                    kubectl port-forward -n monitoring service/"$prometheus_service" $prom_port:9090 &
                    PORT_FORWARD_PIDS+=($!)
                    echo -e "${GREEN}✓ Prometheus available at http://localhost:$prom_port${NC}"
                fi
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Monitoring namespace not found${NC}"
    fi
    
    if [ ${#PORT_FORWARD_PIDS[@]} -gt 0 ]; then
        echo -e "\n${GREEN}Port forwarding started successfully!${NC}"
        echo -e "${YELLOW}Services available:${NC}"
        
        # List available services with their actual ports
        if kubectl get service nimbusguard-service -n nimbusguard &>/dev/null; then
            local ready_pods=$(kubectl get pods -n nimbusguard -l app=nimbusguard --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
            if [ -n "$ready_pods" ]; then
                echo -e "  • NimbusGuard API: http://localhost:8080 (or check above for actual port)"
            fi
        fi
        
        if kubectl get namespace monitoring &>/dev/null; then
            echo -e "  • Grafana: http://localhost:3000+ (check above for actual port) - admin/admin"
            echo -e "  • Prometheus: http://localhost:9090+ (check above for actual port)"
            if kubectl get service prometheus-kube-prometheus-alertmanager -n monitoring &>/dev/null; then
                echo -e "  • Alertmanager: http://localhost:9093+ (check above for actual port)"
            fi
        fi
        
        echo -e "\n${YELLOW}Press Ctrl+C to stop all port forwarding and exit${NC}"
        
        # Function to cleanup on exit
        cleanup_port_forwarding() {
            echo -e "\n${YELLOW}Stopping port forwarding...${NC}"
            for pid in "${PORT_FORWARD_PIDS[@]}"; do
                kill $pid 2>/dev/null || true
            done
            pkill -f "kubectl port-forward" 2>/dev/null || true
            echo -e "${GREEN}✓ Port forwarding stopped${NC}"
            exit 0
        }
        
        # Set trap for cleanup
        trap cleanup_port_forwarding SIGINT SIGTERM
        
        # Wait for processes
        wait
    else
        echo -e "\n${YELLOW}No services available for port forwarding${NC}"
        echo -e "${YELLOW}This could be because:${NC}"
        echo -e "  • Services are not deployed yet"
        echo -e "  • Pods are not ready"
        echo -e "  • Monitoring stack is not installed"
        echo -e "\n${YELLOW}To deploy services, run:${NC}"
        echo -e "  $0 -e $ENVIRONMENT"
        echo -e "\n${YELLOW}To check status, run:${NC}"
        echo -e "  kubectl get all -n nimbusguard"
        echo -e "  kubectl get all -n monitoring"
    fi
}

# Function to perform comprehensive cleanup
perform_cleanup() {
    echo -e "\n${RED}===========================================${NC}"
    echo -e "${RED}      Performing Complete Cleanup         ${NC}"
    echo -e "${RED}===========================================${NC}"
    
    # Stop any port forwarding
    echo -e "\n${YELLOW}Stopping port forwarding processes...${NC}"
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Delete application resources
    echo -e "\n${YELLOW}Cleaning up application resources...${NC}"
    kubectl delete namespace nimbusguard --ignore-not-found=true
    print_status "Application resources cleaned up"
    
    # Delete monitoring resources
    echo -e "\n${YELLOW}Cleaning up monitoring resources...${NC}"
    kubectl delete namespace monitoring --ignore-not-found=true
    print_status "Monitoring resources cleaned up"
    
    echo -e "\n${GREEN}✓ Cleanup completed successfully!${NC}"
}

# Function to check deployment readiness
check_deployment_readiness() {
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}      Checking Deployment Readiness       ${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    local all_ready=true
    
    # Check application
    if kubectl get namespace nimbusguard &>/dev/null; then
        echo -e "\n${YELLOW}Application Status:${NC}"
        local app_replicas=$(kubectl get deployment nimbusguard -n nimbusguard -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local app_desired=$(kubectl get deployment nimbusguard -n nimbusguard -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$app_replicas" = "$app_desired" ] && [ "$app_replicas" != "0" ]; then
            echo -e "${GREEN}✓ Application is ready ($app_replicas/$app_desired replicas)${NC}"
        else
            echo -e "${YELLOW}⚠ Application not fully ready ($app_replicas/$app_desired replicas)${NC}"
            all_ready=false
        fi
        
        kubectl get pods -n nimbusguard
    else
        echo -e "\n${YELLOW}⚠ Application namespace not found${NC}"
        all_ready=false
    fi
    
    # Check monitoring
    if kubectl get namespace monitoring &>/dev/null; then
        echo -e "\n${YELLOW}Monitoring Status:${NC}"
        local monitoring_pods=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l)
        if [ "$monitoring_pods" -gt 0 ]; then
            echo -e "${GREEN}✓ Monitoring namespace exists with $monitoring_pods pods${NC}"
        else
            echo -e "${YELLOW}⚠ Monitoring namespace exists but no pods found${NC}"
        fi
    else
        echo -e "\n${YELLOW}⚠ Monitoring namespace not found${NC}"
    fi
    
    if [ "$all_ready" = true ]; then
        echo -e "\n${GREEN}✓ All services appear to be ready for port forwarding${NC}"
        return 0
    else
        echo -e "\n${YELLOW}⚠ Some services may not be ready. Port forwarding may have limited functionality.${NC}"
        return 1
    fi
}

# Function to show deployment status
show_status() {
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}      Deployment Status Overview          ${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    # Check application status
    if kubectl get namespace nimbusguard &>/dev/null; then
        echo -e "\n${GREEN}Application Status:${NC}"
        kubectl get all -n nimbusguard
        
        echo -e "\n${GREEN}HPA Status:${NC}"
        kubectl get hpa -n nimbusguard 2>/dev/null || echo -e "${YELLOW}  No HPA found${NC}"
        
        echo -e "\n${GREEN}Network Policies:${NC}"
        kubectl get networkpolicy -n nimbusguard 2>/dev/null || echo -e "${YELLOW}  No network policies found${NC}"
    else
        echo -e "\n${YELLOW}Application not deployed${NC}"
    fi
    
    # Check monitoring status
    if kubectl get namespace monitoring &>/dev/null; then
        echo -e "\n${GREEN}Monitoring Status:${NC}"
        kubectl get pods -n monitoring
        
        echo -e "\n${GREEN}Monitoring Services:${NC}"
        kubectl get services -n monitoring
    else
        echo -e "\n${YELLOW}Monitoring not deployed${NC}"
    fi
    
    # Show useful next steps
    echo -e "\n${CYAN}Next Steps:${NC}"
    if kubectl get namespace nimbusguard &>/dev/null; then
        echo -e "  • Start port forwarding: $0 --port-forward-only"
        echo -e "  • View logs: kubectl logs -f deployment/nimbusguard -n nimbusguard"
        echo -e "  • Scale application: kubectl scale deployment/nimbusguard --replicas=3 -n nimbusguard"
    else
        echo -e "  • Deploy application: $0 -e development"
    fi
    
    if kubectl get namespace monitoring &>/dev/null; then
        echo -e "  • Access Grafana: kubectl port-forward -n monitoring service/prometheus-grafana 3000:80"
        echo -e "  • Access Prometheus: kubectl port-forward -n monitoring service/prometheus-kube-prometheus-prometheus 9090:9090"
    else
        echo -e "  • Deploy monitoring: $0 --monitoring-only"
    fi
}

# Function to check if monitoring CRDs are available
check_monitoring_crds() {
    if [ "$DEPLOY_MONITORING" = false ] && [ "$DEPLOY_APP" = true ]; then
        # Check if ServiceMonitor CRD exists
        if ! kubectl get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
            echo -e "${YELLOW}⚠ Warning: ServiceMonitor CRD not found. Monitoring stack may not be installed.${NC}"
            echo -e "${YELLOW}  The application includes ServiceMonitor resources that require Prometheus Operator.${NC}"
            echo -e "${YELLOW}  Consider running with monitoring enabled: $0 --monitoring-only first${NC}"
            read -p "Continue anyway? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                echo -e "${YELLOW}Deployment cancelled.${NC}"
                exit 0
            fi
        fi
    fi
}

# Main execution
main() {
    echo -e "${GREEN}===========================================${NC}"
    echo -e "${GREEN}  NimbusGuard Kubernetes Deployment Tool  ${NC}"
    echo -e "${GREEN}  Environment: $ENVIRONMENT               ${NC}"
    echo -e "${GREEN}===========================================${NC}"

    # Handle cleanup-only mode
    if [ "$CLEANUP_ONLY" = true ]; then
        perform_cleanup
        exit 0
    fi

    # Handle status-only mode
    if [ "$STATUS_ONLY" = true ]; then
        echo -e "\n${YELLOW}Checking deployment status...${NC}"
        check_kubectl
        check_cluster
        show_status
        exit 0
    fi

    # Handle port-forward-only mode
    if [ "$PORT_FORWARD_ONLY" = true ]; then
        echo -e "\n${YELLOW}Starting port forwarding for existing deployment...${NC}"
        check_kubectl
        check_cluster
        
        # Check readiness before starting port forwarding
        if check_deployment_readiness; then
            start_port_forwarding
        else
            echo -e "\n${YELLOW}Proceeding with port forwarding despite readiness issues...${NC}"
            start_port_forwarding
        fi
        exit 0
    fi

    # Check prerequisites
    check_kubectl
    check_kustomize
    check_cluster
    check_monitoring_crds

    # Deploy components based on flags
    # Deploy monitoring first so CRDs are available for ServiceMonitor
    if [ "$DEPLOY_MONITORING" = true ]; then
        deploy_monitoring
    fi

    if [ "$DEPLOY_APP" = true ]; then
        deploy_application
    fi

    # Show status if not dry run
    if [ "$DRY_RUN" = false ]; then
        show_status
    fi

    # Start port forwarding if requested
    if [ "$START_PORT_FORWARDING" = true ] && [ "$DRY_RUN" = false ]; then
        start_port_forwarding
    fi

    echo -e "\n${GREEN}✓ Operation completed successfully!${NC}"
    
    if [ "$DRY_RUN" = false ]; then
        echo -e "\n${CYAN}Useful commands:${NC}"
        echo -e "  View application logs: kubectl logs -f deployment/nimbusguard -n nimbusguard"
        echo -e "  Check application status: kubectl get all -n nimbusguard"
        echo -e "  Start port forwarding: $0 --port-forward-only"
        echo -e "  Clean up everything: $0 --cleanup"
    fi
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 