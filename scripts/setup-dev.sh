#!/bin/bash
set -euo pipefail

# GitOps Express Cluster - Development Setup Script
# This script sets up a local development environment for contributors

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly KIND_CONFIG="${PROJECT_ROOT}/dev/kind-config.yaml"
readonly CLUSTER_NAME="gitops-dev"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Required tools
    if ! command_exists docker; then
        missing_tools+=("docker")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists git; then
        missing_tools+=("git")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and run this script again."
        exit 1
    fi
    
    # Check Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites are satisfied"
}

# Install kind if not present
install_kind() {
    if command_exists kind; then
        log_info "kind is already installed: $(kind version)"
        return
    fi
    
    log_info "Installing kind..."
    
    # Detect OS and architecture
    local os=""
    local arch=""
    
    case "$(uname -s)" in
        Linux*) os="linux" ;;
        Darwin*) os="darwin" ;;
        *) log_error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) log_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
    
    local kind_version="v0.20.0"
    local kind_url="https://kind.sigs.k8s.io/dl/${kind_version}/kind-${os}-${arch}"
    
    # Download and install kind
    curl -Lo ./kind "${kind_url}"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    log_success "kind installed successfully: $(kind version)"
}

# Install additional tools
install_additional_tools() {
    log_info "Installing additional development tools..."
    
    # Install kustomize
    if ! command_exists kustomize; then
        log_info "Installing kustomize..."
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
        log_success "kustomize installed"
    fi
    
    # Install ArgoCD CLI
    if ! command_exists argocd; then
        log_info "Installing ArgoCD CLI..."
        local argocd_version="v2.8.4"
        curl -sSL -o argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/${argocd_version}/argocd-linux-amd64"
        chmod +x argocd-linux-amd64
        sudo mv argocd-linux-amd64 /usr/local/bin/argocd
        log_success "ArgoCD CLI installed"
    fi
    
    # Install Tekton CLI
    if ! command_exists tkn; then
        log_info "Installing Tekton CLI..."
        local tkn_version="0.32.0"
        curl -LO "https://github.com/tektoncd/cli/releases/download/v${tkn_version}/tkn_${tkn_version}_Linux_x86_64.tar.gz"
        tar xvzf "tkn_${tkn_version}_Linux_x86_64.tar.gz" -C /tmp
        sudo mv /tmp/tkn /usr/local/bin/
        rm "tkn_${tkn_version}_Linux_x86_64.tar.gz"
        log_success "Tekton CLI installed"
    fi
}

# Create kind configuration
create_kind_config() {
    log_info "Creating kind configuration..."
    
    mkdir -p "$(dirname "${KIND_CONFIG}")"
    
    cat > "${KIND_CONFIG}" << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: gitops-dev
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
- role: worker
- role: worker
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
EOF
    
    log_success "kind configuration created at ${KIND_CONFIG}"
}

# Create development cluster
create_cluster() {
    log_info "Creating development cluster..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_warning "Cluster '${CLUSTER_NAME}' already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name "${CLUSTER_NAME}"
        else
            log_info "Using existing cluster"
            return
        fi
    fi
    
    # Create cluster
    kind create cluster --config="${KIND_CONFIG}"
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "Development cluster created successfully"
}

# Install core components
install_core_components() {
    log_info "Installing core components..."
    
    # Create development namespace
    kubectl create namespace gitops-dev --dry-run=client -o yaml | kubectl apply -f -
    
    # Install NGINX Ingress Controller
    log_info "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress controller
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Install ArgoCD
    log_info "Installing ArgoCD..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Install Tekton Pipelines
    log_info "Installing Tekton Pipelines..."
    kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
    
    # Wait for Tekton
    kubectl wait --for=condition=available --timeout=300s deployment/tekton-pipelines-controller -n tekton-pipelines
    
    log_success "Core components installed successfully"
}

# Setup development tools
setup_dev_tools() {
    log_info "Setting up development tools..."
    
    # Create useful aliases
    cat > "${PROJECT_ROOT}/dev/aliases.sh" << 'EOF'
#!/bin/bash
# Development aliases for GitOps Express Cluster

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgi='kubectl get ingress'
alias kns='kubectl config set-context --current --namespace'

# ArgoCD aliases
alias argo='argocd'
alias argopass='kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'

# Tekton aliases
alias tkn-logs='tkn pipelinerun logs --last -f'
alias tkn-list='tkn pipelinerun list'

# Development helpers
alias dev-cluster='kind get kubeconfig --name=gitops-dev'
alias dev-reset='kind delete cluster --name=gitops-dev && ./scripts/setup-dev.sh'

# Port forwarding helpers
alias argocd-ui='kubectl port-forward svc/argocd-server -n argocd 8080:443'
alias grafana-ui='kubectl port-forward svc/grafana -n monitoring 3000:3000'

echo "Development aliases loaded! 🚀"
echo ""
echo "Useful commands:"
echo "  kns <namespace>     - Switch to namespace"
echo "  argopass           - Get ArgoCD admin password"
echo "  argocd-ui          - Port forward ArgoCD UI to localhost:8080"
echo "  dev-reset          - Reset development cluster"
EOF
    
    # Create development configuration
    cat > "${PROJECT_ROOT}/dev/config.env" << EOF
# Development environment configuration
export CLUSTER_NAME=${CLUSTER_NAME}
export KUBECONFIG=$(kind get kubeconfig-path --name=${CLUSTER_NAME} 2>/dev/null || echo "~/.kube/config")
export ARGOCD_SERVER=localhost:8080
export ARGOCD_OPTS="--insecure"

# Application configuration
export APP_NAME=nodejs-app
export APP_NAMESPACE=gitops-dev
export DOCKER_REGISTRY=localhost:5000
export GIT_REPO_URL=https://github.com/nguie2/gitops-express-cluster.git
EOF
    
    log_success "Development tools configured"
}

# Display next steps
show_next_steps() {
    log_success "Development environment setup complete! 🎉"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Source the development aliases:"
    echo "   source dev/aliases.sh"
    echo ""
    echo "2. Load environment variables:"
    echo "   source dev/config.env"
    echo ""
    echo "3. Get ArgoCD admin password:"
    echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    echo ""
    echo "4. Access ArgoCD UI:"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   Open: https://localhost:8080 (admin/[password from step 3])"
    echo ""
    echo "5. Start developing:"
    echo "   - Edit manifests in k8s/"
    echo "   - Test with: kubectl apply -k k8s/base/"
    echo "   - Create pull requests with changes"
    echo ""
    echo "Useful development commands:"
    echo "   ./scripts/test-integration.sh  - Run integration tests"
    echo "   ./scripts/lint.sh             - Lint code and manifests"
    echo "   kind delete cluster --name=${CLUSTER_NAME}  - Clean up cluster"
    echo ""
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Setup failed! Check the logs above for details."
        echo ""
        echo "To cleanup and try again:"
        echo "   kind delete cluster --name=${CLUSTER_NAME}"
        echo "   ./scripts/setup-dev.sh"
    fi
}

# Main function
main() {
    trap cleanup EXIT
    
    echo "🚀 GitOps Express Cluster - Development Setup"
    echo "=============================================="
    echo ""
    
    check_prerequisites
    install_kind
    install_additional_tools
    create_kind_config
    create_cluster
    install_core_components
    setup_dev_tools
    show_next_steps
    
    trap - EXIT
}

# Run main function
main "$@" 