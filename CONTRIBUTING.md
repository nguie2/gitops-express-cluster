# 🤝 Contributing to GitOps Express Cluster

Thank you for your interest in contributing to the GitOps Express Cluster project! This guide will help you get started with contributing to this enterprise-grade Kubernetes GitOps pipeline.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Process](#contributing-process)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation Guidelines](#documentation-guidelines)
- [Issue Reporting](#issue-reporting)
- [Community Guidelines](#community-guidelines)

## 📜 Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

### Our Pledge

We are committed to making participation in this project a harassment-free experience for everyone, regardless of:
- Age, body size, disability, ethnicity, gender identity and expression
- Level of experience, nationality, personal appearance, race, religion
- Sexual identity and orientation

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have the following installed:

- **Git** (2.20+)
- **Docker** (20.10+)
- **Kubernetes CLI (kubectl)** (1.24+)
- **Helm** (3.8+)
- **Node.js** (18+) and npm
- **Go** (1.19+) for some tools
- **Python** (3.9+) for scripts

### Recommended Tools

- **ArgoCD CLI**: `curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64`
- **Tekton CLI**: `curl -LO https://github.com/tektoncd/cli/releases/latest/download/tkn_0.32.0_Linux_x86_64.tar.gz`
- **Kustomize**: `curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash`

## 🛠️ Development Setup

### 1. Fork and Clone the Repository

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/your-username/gitops-express-cluster.git
cd gitops-express-cluster

# Add the original repository as upstream
git remote add upstream https://github.com/nguie2/gitops-express-cluster.git
```

### 2. Set Up Development Environment

```bash
# Create a new branch for your changes
git checkout -b feature/your-feature-name

# Install development dependencies
npm install  # For Node.js components
pip install -r requirements-dev.txt  # For Python scripts

# Set up pre-commit hooks
pre-commit install
```

### 3. Local Kubernetes Cluster Setup

Choose one of the following for local development:

#### Option A: Kind (Recommended)
```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create local cluster
kind create cluster --config=dev/kind-config.yaml
```

#### Option B: k3d
```bash
# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create local cluster
k3d cluster create gitops-dev --port "8080:80@loadbalancer"
```

#### Option C: Minikube
```bash
# Start minikube
minikube start --memory=8192 --cpus=4
minikube addons enable ingress
```

### 4. Install Core Components

```bash
# Apply development configuration
kubectl apply -f dev/namespace.yaml

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Install Tekton
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

## 🔄 Contributing Process

### 1. Choose an Issue

- Check our [Issues](https://github.com/nguie2/gitops-express-cluster/issues) for open tasks
- Look for issues labeled `good first issue` or `help wanted`
- Comment on the issue to let others know you're working on it

### 2. Create a Feature Branch

```bash
# Ensure you're on the main branch and up to date
git checkout main
git pull upstream main

# Create a new feature branch
git checkout -b feature/issue-number-short-description
# Example: git checkout -b feature/123-add-azure-support
```

### 3. Make Your Changes

- Follow our [Coding Standards](#coding-standards)
- Write tests for new functionality
- Update documentation as needed
- Ensure your changes don't break existing functionality

### 4. Test Your Changes

```bash
# Run linting
npm run lint  # For JavaScript/TypeScript
flake8 .      # For Python
yamllint .    # For YAML files

# Run tests
npm test                    # Unit tests
pytest tests/              # Python tests
./scripts/test-integration.sh  # Integration tests

# Test Kubernetes manifests
kubectl apply --dry-run=client -f k8s/base/
kustomize build k8s/overlays/dev | kubectl apply --dry-run=client -f -
```

### 5. Commit Your Changes

Follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

```bash
# Stage your changes
git add .

# Commit with conventional commit message
git commit -m "feat: add Azure AKS deployment support

- Add AKS-specific ingress configuration
- Include Azure Monitor integration
- Update documentation with AKS setup guide

Closes #123"
```

#### Commit Message Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes
- `perf`: Performance improvements

### 6. Push and Create Pull Request

```bash
# Push your branch to your fork
git push origin feature/issue-number-short-description

# Create a pull request on GitHub
# Use the pull request template and fill in all sections
```

## 📝 Pull Request Guidelines

### Before Submitting

- [ ] I have read the contributing guidelines
- [ ] My code follows the project's coding standards
- [ ] I have tested my changes locally
- [ ] I have added tests for new functionality
- [ ] I have updated documentation as needed
- [ ] My commits follow the conventional commit format
- [ ] I have rebased my branch on the latest main

### Pull Request Template

When creating a pull request, use this template:

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring (no functional changes)

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Tested on multiple environments (if applicable)

## Screenshots/Demo
If applicable, add screenshots or demo links.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes without version bump
- [ ] Tests added/updated
- [ ] All CI checks pass

## Related Issues
Closes #(issue number)
```

### Review Process

1. **Automated Checks**: All CI/CD checks must pass
2. **Code Review**: At least one maintainer review required
3. **Testing**: Reviewer will test changes in staging environment
4. **Documentation**: Ensure docs are updated and accurate
5. **Approval**: Once approved, maintainer will merge

## 💻 Coding Standards

### YAML Files

```yaml
# Use 2-space indentation
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
  labels:
    app: example-app
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example-app
```

**YAML Guidelines:**
- Use 2 spaces for indentation
- Keep lines under 120 characters
- Use meaningful names and labels
- Include resource limits and requests
- Add security contexts where applicable

### Shell Scripts

```bash
#!/bin/bash
set -euo pipefail

# Use descriptive variable names
readonly CLUSTER_NAME="gitops-express-cluster"
readonly NAMESPACE="nodejs-app"

# Function documentation
# Deploys application to Kubernetes cluster
deploy_application() {
    local -r app_name="${1}"
    local -r version="${2}"
    
    echo "Deploying ${app_name} version ${version}..."
    kubectl apply -f "manifests/${app_name}/"
}

# Main execution
main() {
    deploy_application "nodejs-app" "v1.0.0"
}

main "$@"
```

**Shell Script Guidelines:**
- Use `#!/bin/bash` and `set -euo pipefail`
- Use `readonly` for constants
- Use `local -r` for function parameters
- Include error handling
- Add comments for complex logic

### Documentation

```markdown
# Title (H1)

Brief description of the component or feature.

## Prerequisites (H2)

List what's needed before following the guide.

### Installation (H3)

Step-by-step instructions with code blocks:

```bash
kubectl apply -f manifest.yaml
```

## Configuration

Explain configuration options with examples.
```

**Documentation Guidelines:**
- Use clear, concise language
- Include code examples for all procedures
- Add prerequisites sections
- Use proper markdown formatting
- Include troubleshooting sections

## 🧪 Testing Requirements

### Unit Tests

```bash
# JavaScript/TypeScript
npm test

# Python
pytest tests/unit/

# Go
go test ./...
```

### Integration Tests

```bash
# Run full integration test suite
./scripts/test-integration.sh

# Test specific component
./scripts/test-component.sh argocd
./scripts/test-component.sh tekton
```

### Kubernetes Manifest Tests

```bash
# Validate YAML syntax
yamllint k8s/

# Test with kubeval
kubeval k8s/base/*.yaml

# Test with conftest (OPA policies)
conftest verify --policy policies/ k8s/base/
```

### Security Tests

```bash
# Scan for security issues
./scripts/security-scan.sh

# Check for secrets in code
./scripts/check-secrets.sh

# Validate RBAC policies
./scripts/validate-rbac.sh
```

## 📚 Documentation Guidelines

### When to Update Documentation

- Adding new features or components
- Changing existing functionality
- Fixing bugs that affect user experience
- Adding new deployment targets (cloud providers)
- Updating dependencies or requirements

### Documentation Structure

```
docs/
├── setup/           # Installation and setup guides
├── architecture/    # Technical architecture docs
├── runbooks/        # Operational procedures
├── troubleshooting/ # Common issues and solutions
├── examples/        # Usage examples
└── api/            # API documentation
```

### Writing Style

- Use active voice
- Write in second person ("you can", "you should")
- Include practical examples
- Add warning boxes for important notes
- Use consistent terminology throughout

## 🐛 Issue Reporting

### Bug Reports

Use the bug report template:

```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment (please complete the following information):**
- OS: [e.g. Ubuntu 22.04]
- Kubernetes Version: [e.g. 1.27.0]
- ArgoCD Version: [e.g. 2.8.0]
- Browser: [e.g. chrome, safari]

**Additional context**
Add any other context about the problem here.
```

### Feature Requests

Use the feature request template:

```markdown
**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions.

**Additional context**
Add any other context or screenshots about the feature request here.
```

## 👥 Community Guidelines

### Communication Channels

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: General questions, ideas
- **Slack/Discord**: Real-time chat (link in README)
- **Email**: Security issues only

### Getting Help

1. Check existing documentation
2. Search closed issues
3. Ask in GitHub Discussions
4. Join our community chat

### Being a Good Community Member

- Be respectful and inclusive
- Help others when you can
- Share knowledge and experiences
- Provide constructive feedback
- Follow the code of conduct

## 🏆 Recognition

Contributors will be recognized in:

- **README.md**: Contributors section
- **CHANGELOG.md**: Feature contributions
- **GitHub Releases**: Major contributions
- **Community Highlights**: Monthly recognition

## 📞 Getting Help

If you need help with contributing:

1. **Check Documentation**: Start with this guide and the README
2. **Search Issues**: Look for similar questions or problems
3. **Ask Questions**: Open a discussion or issue
4. **Join Community**: Connect with other contributors

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

## 🙏 Thank You

Thank you for taking the time to contribute to GitOps Express Cluster! Your contributions help make this project better for everyone in the DevOps community.

For questions about contributing, please reach out to:

**Nguie Angoue Jean Roch Junior**
- 📧 Email: [nguierochjunior@gmail.com](mailto:nguierochjunior@gmail.com)
- 🐙 GitHub: [@nguie2](https://github.com/nguie2)
- 💼 LinkedIn: [Nguie Angoue J.](https://www.linkedin.com/in/nguie-angoue-j-2b2880254/)

*Happy contributing! 🚀* 