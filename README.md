# NetBox on OpenShift with ArgoCD

This repository contains the Kubernetes/OpenShift manifests to deploy NetBox, an open-source IPAM (IP Address Management) and DCIM (Data Center Infrastructure Management) application, on OpenShift using ArgoCD for GitOps-based continuous deployment.

## Architecture

The deployment consists of three main components:

1. **PostgreSQL Database** - Primary data store for NetBox
2. **Redis Cache** - Caching and task queue backend
3. **NetBox Application** - The main NetBox web application

## Repository Structure

```
.
├── k8s/
│   ├── base/                      # Base Kubernetes manifests
│   │   ├── postgres/              # PostgreSQL deployment
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── pvc.yaml
│   │   │   ├── secret.yaml
│   │   │   └── kustomization.yaml
│   │   ├── redis/                 # Redis deployment
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── pvc.yaml
│   │   │   └── kustomization.yaml
│   │   └── netbox/                # NetBox deployment
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── route.yaml
│   │       ├── pvc.yaml
│   │       ├── configmap.yaml
│   │       ├── secret.yaml
│   │       └── kustomization.yaml
│   ├── overlays/                  # Environment-specific overlays
│   │   ├── dev/                   # Development environment
│   │   │   └── kustomization.yaml
│   │   └── prod/                  # Production environment
│   │       └── kustomization.yaml
│   └── argocd/                    # ArgoCD Application definitions
│       ├── appproject.yaml
│       ├── netbox-dev.yaml
│       └── netbox-prod.yaml
└── README.md
```

## Prerequisites

- OpenShift cluster (ROSA, OCP, OKD, or any OpenShift-compatible cluster)
- ArgoCD or OpenShift GitOps operator installed
- `kubectl` or `oc` CLI tool
- `kustomize` (optional, for local testing)
- Git repository to host this code

## Quick Start

### 1. Fork/Clone this Repository

```bash
git clone https://github.com/your-org/netbox-rosa.git
cd netbox-rosa
```

### 2. Update Configuration

Before deploying, update the following files:

#### Update Git Repository URLs

Edit the ArgoCD application manifests:
- `k8s/argocd/appproject.yaml`
- `k8s/argocd/netbox-dev.yaml`
- `k8s/argocd/netbox-prod.yaml`

Replace `https://github.com/your-org/netbox-rosa.git` with your actual repository URL.

#### Update Route Hostnames

Edit the overlay kustomization files:
- `k8s/overlays/dev/kustomization.yaml`
- `k8s/overlays/prod/kustomization.yaml`

Update the route hostnames to match your OpenShift cluster's domain:
```yaml
# Example:
- op: add
  path: /spec/host
  value: netbox-dev.apps.your-cluster.example.com
```

#### Update Secrets (IMPORTANT!)

**IMPORTANT**: Change the default passwords and secrets before deploying to production!

1. **PostgreSQL Password** (`k8s/base/postgres/secret.yaml`):
   ```yaml
   POSTGRES_PASSWORD: your-secure-password-here
   ```

2. **NetBox Secret Key** (`k8s/base/netbox/secret.yaml`):
   Generate a secure random key:
   ```bash
   python3 -c 'import secrets; print(secrets.token_urlsafe(50))'
   ```

   Update the values:
   ```yaml
   SECRET_KEY: your-generated-secret-key
   SUPERUSER_PASSWORD: your-admin-password
   SUPERUSER_API_TOKEN: your-api-token
   ```

### 3. Deploy with ArgoCD

#### Option A: Using ArgoCD CLI

```bash
# Login to ArgoCD
argocd login <argocd-server>

# Create the AppProject
oc apply -f k8s/argocd/appproject.yaml

# Deploy to dev environment
oc apply -f k8s/argocd/netbox-dev.yaml

# Deploy to prod environment (when ready)
oc apply -f k8s/argocd/netbox-prod.yaml
```

#### Option B: Using kubectl/oc

```bash
# Apply ArgoCD manifests
oc apply -f k8s/argocd/

# ArgoCD will automatically sync the applications
```

### 4. Monitor Deployment

```bash
# Watch ArgoCD applications
argocd app list
argocd app get netbox-dev

# Watch pods in the namespace
oc get pods -n netbox-dev -w

# Check application logs
oc logs -f -n netbox-dev -l app=netbox
```

### 5. Access NetBox

Once deployed, get the route URL:

```bash
# For dev environment
oc get route -n netbox-dev

# For prod environment
oc get route -n netbox-prod
```

Access NetBox using the route URL. Default credentials:
- **Username**: `admin`
- **Password**: Check `k8s/base/netbox/secret.yaml` (change this!)

## Manual Deployment (Without ArgoCD)

If you want to deploy manually without ArgoCD:

```bash
# Deploy to dev environment
oc apply -k k8s/overlays/dev

# Deploy to prod environment
oc apply -k k8s/overlays/prod
```

## Development Environment Setup

This repository is designed to be used as a development environment for NetBox plugins.

### Adding NetBox Plugins

To add plugins to your NetBox deployment:

1. Create a custom Dockerfile extending the official NetBox image:

```dockerfile
FROM netboxcommunity/netbox:latest

# Install your plugins
COPY requirements.txt /opt/netbox/
RUN pip install -r /opt/netbox/requirements.txt

# Copy plugin configurations if needed
COPY plugins/ /opt/netbox/netbox/plugins/
```

2. Build and push the custom image:

```bash
docker build -t your-registry/netbox-custom:latest .
docker push your-registry/netbox-custom:latest
```

3. Update the NetBox deployment to use your custom image:

```yaml
# In k8s/overlays/dev/kustomization.yaml
images:
  - name: netboxcommunity/netbox
    newName: your-registry/netbox-custom
    newTag: latest
```

### Developing Plugins Locally

1. Create a local development directory structure:

```bash
mkdir -p plugins/my-plugin
```

2. Use a ConfigMap or PVC to mount your plugin code:

```yaml
# Add to deployment
volumeMounts:
  - name: plugin-code
    mountPath: /opt/netbox/netbox/plugins/my-plugin

volumes:
  - name: plugin-code
    configMap:
      name: my-plugin-code
```

3. Configure NetBox to load the plugin by updating the ConfigMap:

```yaml
# k8s/base/netbox/configmap.yaml
data:
  PLUGINS: "['my-plugin']"
  PLUGINS_CONFIG: |
    {
      "my-plugin": {
        "option1": "value1"
      }
    }
```

## Maintenance Tasks

### Database Migrations

Migrations run automatically in the init container. To run manually:

```bash
oc exec -it -n netbox-dev deployment/netbox -- python3 /opt/netbox/netbox/manage.py migrate
```

### Create Superuser

```bash
oc exec -it -n netbox-dev deployment/netbox -- python3 /opt/netbox/netbox/manage.py createsuperuser
```

### Backup Database

```bash
# Get the postgres pod name
POD=$(oc get pod -n netbox-dev -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Backup
oc exec -n netbox-dev $POD -- pg_dump -U netbox netbox > netbox-backup-$(date +%Y%m%d).sql
```

### Restore Database

```bash
# Get the postgres pod name
POD=$(oc get pod -n netbox-dev -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Restore
cat netbox-backup.sql | oc exec -i -n netbox-dev $POD -- psql -U netbox netbox
```

## Customization

### Resource Limits

Adjust resource limits in the overlay kustomization files based on your needs:

```yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "4Gi"
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/cpu
        value: "2000m"
    target:
      kind: Deployment
      name: netbox
```

### Storage

Update PVC sizes in the overlay kustomization files:

```yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/resources/requests/storage
        value: "100Gi"
    target:
      kind: PersistentVolumeClaim
      name: postgres-pvc
```

### Environment Variables

Add or modify environment variables in the ConfigMap:

```yaml
# k8s/base/netbox/configmap.yaml or in overlays
data:
  YOUR_ENV_VAR: "value"
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
oc get pods -n netbox-dev

# Check pod events
oc describe pod -n netbox-dev <pod-name>

# Check logs
oc logs -n netbox-dev <pod-name>
```

### Database Connection Issues

```bash
# Check if postgres is running
oc get pods -n netbox-dev -l app=postgres

# Check postgres logs
oc logs -n netbox-dev -l app=postgres

# Test database connection from netbox pod
oc exec -it -n netbox-dev deployment/netbox -- \
  psql -h postgres -U netbox -d netbox
```

### ArgoCD Sync Issues

```bash
# Check application status
argocd app get netbox-dev

# Force sync
argocd app sync netbox-dev

# Check for differences
argocd app diff netbox-dev
```

## Security Considerations

1. **Secrets Management**: Consider using OpenShift's Sealed Secrets or External Secrets Operator for production deployments
2. **Network Policies**: Implement network policies to restrict traffic between components
3. **RBAC**: Configure proper RBAC rules for accessing NetBox resources
4. **Image Security**: Use specific image tags instead of `latest` in production
5. **TLS**: Routes use edge TLS termination by default, consider using cert-manager for automatic certificate management

## Contributing

1. Create a feature branch
2. Make your changes
3. Test in dev environment
4. Submit a pull request

## Resources

- [NetBox Documentation](https://docs.netbox.dev/)
- [NetBox Docker Image](https://github.com/netbox-community/netbox-docker)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Kustomize Documentation](https://kustomize.io/)

## License

This deployment configuration is provided as-is. NetBox itself is licensed under Apache 2.0.
