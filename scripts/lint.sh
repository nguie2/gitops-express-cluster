#!/bin/bash
set -euo pipefail

# GitOps Express Cluster - Linting Script
# This script runs various linters and quality checks

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

# Install linting tools if not present
install_linters() {
    log_info "Installing linting tools..."
    
    # Install yamllint
    if ! command_exists yamllint; then
        log_info "Installing yamllint..."
        pip3 install --user yamllint
    fi
    
    # Install kubeval
    if ! command_exists kubeval; then
        log_info "Installing kubeval..."
        local kubeval_version="v0.16.1"
        curl -sSLo kubeval.tar.gz "https://github.com/instrumenta/kubeval/releases/download/${kubeval_version}/kubeval-linux-amd64.tar.gz"
        tar xf kubeval.tar.gz
        sudo mv kubeval /usr/local/bin
        rm kubeval.tar.gz
    fi
    
    # Install shellcheck
    if ! command_exists shellcheck; then
        log_info "Installing shellcheck..."
        sudo apt-get update && sudo apt-get install -y shellcheck || {
            log_warning "Could not install shellcheck via apt. Please install manually."
        }
    fi
    
    # Install hadolint (Dockerfile linter)
    if ! command_exists hadolint; then
        log_info "Installing hadolint..."
        curl -sSLo hadolint "https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64"
        chmod +x hadolint
        sudo mv hadolint /usr/local/bin/
    fi
}

# Lint YAML files
lint_yaml() {
    log_info "Linting YAML files..."
    
    local yaml_config="${PROJECT_ROOT}/.yamllint.yml"
    
    # Create yamllint config if it doesn't exist
    if [ ! -f "${yaml_config}" ]; then
        cat > "${yaml_config}" << 'EOF'
extends: default

rules:
  line-length:
    max: 120
    level: warning
  indentation:
    spaces: 2
  comments:
    min-spaces-from-content: 1
  document-start:
    present: false
  truthy:
    allowed-values: ['true', 'false', 'on', 'off']
EOF
    fi
    
    local yaml_files
    yaml_files=$(find "${PROJECT_ROOT}" -name "*.yaml" -o -name "*.yml" | grep -v ".git" | grep -v "node_modules" || true)
    
    if [ -z "${yaml_files}" ]; then
        log_warning "No YAML files found to lint"
        return 0
    fi
    
    local yaml_errors=0
    while IFS= read -r file; do
        if ! yamllint -c "${yaml_config}" "${file}"; then
            log_error "YAML lint failed for: ${file}"
            ((yaml_errors++))
        fi
    done <<< "${yaml_files}"
    
    if [ ${yaml_errors} -eq 0 ]; then
        log_success "All YAML files passed linting"
    else
        log_error "YAML linting failed for ${yaml_errors} files"
        return 1
    fi
}

# Validate Kubernetes manifests
validate_k8s() {
    log_info "Validating Kubernetes manifests..."
    
    local k8s_errors=0
    
    # Validate base manifests
    local base_files
    base_files=$(find "${PROJECT_ROOT}/k8s/base" -name "*.yaml" -o -name "*.yml" 2>/dev/null || true)
    
    if [ -n "${base_files}" ]; then
        while IFS= read -r file; do
            if ! kubeval "${file}"; then
                log_error "Kubernetes validation failed for: ${file}"
                ((k8s_errors++))
            fi
        done <<< "${base_files}"
    fi
    
    # Validate overlay manifests
    local overlay_dirs
    overlay_dirs=$(find "${PROJECT_ROOT}/k8s/overlays" -type d -mindepth 1 -maxdepth 1 2>/dev/null || true)
    
    if [ -n "${overlay_dirs}" ]; then
        while IFS= read -r dir; do
            if command_exists kustomize; then
                if ! kustomize build "${dir}" | kubeval; then
                    log_error "Kubernetes validation failed for overlay: ${dir}"
                    ((k8s_errors++))
                fi
            else
                log_warning "kustomize not found, skipping overlay validation for: ${dir}"
            fi
        done <<< "${overlay_dirs}"
    fi
    
    if [ ${k8s_errors} -eq 0 ]; then
        log_success "All Kubernetes manifests are valid"
    else
        log_error "Kubernetes validation failed for ${k8s_errors} manifests"
        return 1
    fi
}

# Lint shell scripts
lint_shell() {
    log_info "Linting shell scripts..."
    
    local shell_files
    shell_files=$(find "${PROJECT_ROOT}" -name "*.sh" | grep -v ".git" | grep -v "node_modules" || true)
    
    if [ -z "${shell_files}" ]; then
        log_warning "No shell scripts found to lint"
        return 0
    fi
    
    local shell_errors=0
    while IFS= read -r file; do
        if ! shellcheck "${file}"; then
            log_error "Shell script lint failed for: ${file}"
            ((shell_errors++))
        fi
    done <<< "${shell_files}"
    
    if [ ${shell_errors} -eq 0 ]; then
        log_success "All shell scripts passed linting"
    else
        log_error "Shell script linting failed for ${shell_errors} files"
        return 1
    fi
}

# Lint Dockerfile
lint_dockerfile() {
    log_info "Linting Dockerfile..."
    
    local dockerfile="${PROJECT_ROOT}/Dockerfile"
    
    if [ ! -f "${dockerfile}" ]; then
        log_warning "No Dockerfile found to lint"
        return 0
    fi
    
    if ! hadolint "${dockerfile}"; then
        log_error "Dockerfile linting failed"
        return 1
    fi
    
    log_success "Dockerfile passed linting"
}

# Check for secrets and sensitive data
check_secrets() {
    log_info "Checking for secrets and sensitive data..."
    
    local secret_patterns=(
        "password"
        "secret"
        "token"
        "api[_-]?key"
        "private[_-]?key"
        "access[_-]?key"
        "auth[_-]?token"
        "credential"
    )
    
    local secrets_found=0
    
    for pattern in "${secret_patterns[@]}"; do
        local matches
        matches=$(grep -ri "${pattern}" "${PROJECT_ROOT}" \
            --exclude-dir=".git" \
            --exclude-dir="node_modules" \
            --exclude="*.md" \
            --exclude="CONTRIBUTING.md" \
            --exclude="CODE_OF_CONDUCT.md" \
            --exclude="$(basename "$0")" \
            || true)
        
        if [ -n "${matches}" ]; then
            log_warning "Potential secret found with pattern '${pattern}':"
            echo "${matches}"
            ((secrets_found++))
        fi
    done
    
    if [ ${secrets_found} -eq 0 ]; then
        log_success "No potential secrets found"
    else
        log_warning "Found ${secrets_found} potential secret patterns. Please review."
    fi
}

# Check Git configuration
check_git() {
    log_info "Checking Git configuration..."
    
    # Check for large files
    local large_files
    large_files=$(find "${PROJECT_ROOT}" -type f -size +10M | grep -v ".git" || true)
    
    if [ -n "${large_files}" ]; then
        log_warning "Large files found (>10MB):"
        echo "${large_files}"
    fi
    
    # Check for binary files that shouldn't be tracked
    local binary_extensions=("*.exe" "*.dll" "*.so" "*.dylib" "*.jar" "*.war")
    local binary_found=0
    
    for ext in "${binary_extensions[@]}"; do
        local files
        files=$(find "${PROJECT_ROOT}" -name "${ext}" | grep -v ".git" || true)
        if [ -n "${files}" ]; then
            log_warning "Binary files found with extension ${ext}:"
            echo "${files}"
            ((binary_found++))
        fi
    done
    
    if [ ${binary_found} -eq 0 ] && [ -z "${large_files}" ]; then
        log_success "Git repository looks clean"
    fi
}

# Run security checks
run_security_checks() {
    log_info "Running security checks..."
    
    # Check for insecure configurations
    local insecure_patterns=(
        "runAsRoot.*true"
        "privileged.*true"
        "allowPrivilegeEscalation.*true"
        "hostNetwork.*true"
        "hostPID.*true"
        "hostIPC.*true"
    )
    
    local security_issues=0
    
    for pattern in "${insecure_patterns[@]}"; do
        local matches
        matches=$(grep -r "${pattern}" "${PROJECT_ROOT}/k8s" || true)
        
        if [ -n "${matches}" ]; then
            log_warning "Potential security issue found with pattern '${pattern}':"
            echo "${matches}"
            ((security_issues++))
        fi
    done
    
    if [ ${security_issues} -eq 0 ]; then
        log_success "No obvious security issues found"
    else
        log_warning "Found ${security_issues} potential security issues. Please review."
    fi
}

# Generate lint report
generate_report() {
    local report_file="${PROJECT_ROOT}/lint-report.txt"
    
    log_info "Generating lint report..."
    
    cat > "${report_file}" << EOF
GitOps Express Cluster - Lint Report
Generated: $(date)
========================================

Project Root: ${PROJECT_ROOT}
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "Not a git repository")
Branch: $(git branch --show-current 2>/dev/null || echo "Unknown")

Files Checked:
- YAML files: $(find "${PROJECT_ROOT}" -name "*.yaml" -o -name "*.yml" | wc -l)
- Shell scripts: $(find "${PROJECT_ROOT}" -name "*.sh" | wc -l)
- Kubernetes manifests: $(find "${PROJECT_ROOT}/k8s" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l || echo "0")
- Dockerfiles: $(find "${PROJECT_ROOT}" -name "Dockerfile*" | wc -l)

Linting Tools Used:
- yamllint: $(yamllint --version 2>/dev/null || echo "Not available")
- kubeval: $(kubeval --version 2>/dev/null || echo "Not available")
- shellcheck: $(shellcheck --version 2>/dev/null | head -n1 || echo "Not available")
- hadolint: $(hadolint --version 2>/dev/null || echo "Not available")

Results: See output above
EOF
    
    log_success "Lint report generated: ${report_file}"
}

# Main function
main() {
    echo "🔍 GitOps Express Cluster - Code Quality Checks"
    echo "==============================================="
    echo ""
    
    cd "${PROJECT_ROOT}"
    
    local exit_code=0
    
    # Install tools if needed
    install_linters
    
    # Run linting checks
    lint_yaml || exit_code=1
    echo ""
    
    validate_k8s || exit_code=1
    echo ""
    
    lint_shell || exit_code=1
    echo ""
    
    lint_dockerfile || exit_code=1
    echo ""
    
    check_secrets
    echo ""
    
    check_git
    echo ""
    
    run_security_checks
    echo ""
    
    generate_report
    
    if [ ${exit_code} -eq 0 ]; then
        log_success "All linting checks passed! ✅"
    else
        log_error "Some linting checks failed! ❌"
        echo ""
        echo "Please fix the issues above and run the linter again."
    fi
    
    exit ${exit_code}
}

# Run main function
main "$@" 