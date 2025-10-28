# NetBox on OpenShift - Quick Start Guide

This guide will get you up and running with NetBox on OpenShift in under 10 minutes.

## Prerequisites Checklist

- [ ] OpenShift cluster access (ROSA/OCP/OKD)
- [ ] ArgoCD or OpenShift GitOps operator installed
- [ ] `oc` CLI logged in to your cluster
- [ ] This repository forked/cloned

## 5-Minute Deployment

### Step 1: Configure Secrets (2 minutes)

Generate a secure secret key:
```bash
python3 -c 'import secrets; print(secrets.token_urlsafe(50))'
```

Edit `k8s/base/netbox/secret.yaml` and update:
- `SECRET_KEY` - use the generated key above
- `SUPERUSER_PASSWORD` - choose a strong password
- `SUPERUSER_API_TOKEN` - generate another random token

Edit `k8s/base/postgres/secret.yaml` and update:
- `POSTGRES_PASSWORD` - choose a strong password

### Step 2: Update Repository URL (1 minute)

Edit these files and replace `https://github.com/your-org/netbox-rosa.git` with your actual repository URL:
- `k8s/argocd/appproject.yaml`
- `k8s/argocd/netbox-dev.yaml`
- `k8s/argocd/netbox-prod.yaml`

### Step 3: Update Route Hostname (1 minute)

Edit `k8s/overlays/dev/kustomization.yaml`:
```yaml
# Find this section and update the hostname
- patch: |-
    - op: add
      path: /spec/host
      value: netbox-dev.apps.YOUR-CLUSTER-DOMAIN.com  # Update this!
```

Get your cluster domain:
```bash
oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'
```

### Step 4: Deploy with ArgoCD (1 minute)

```bash
# Apply ArgoCD applications
oc apply -f k8s/argocd/

# Watch the deployment
oc get pods -n netbox-dev -w
```

Or deploy manually without ArgoCD:
```bash
oc apply -k k8s/overlays/dev
```

### Step 5: Access NetBox

Get your route URL:
```bash
oc get route -n netbox-dev
```

Open the URL in your browser and login with:
- **Username**: `admin`
- **Password**: (the one you set in step 1)

## Verification Checklist

```bash
# Check all pods are running
oc get pods -n netbox-dev

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# dev-postgres-xxxxx            1/1     Running   0          5m
# dev-redis-xxxxx               1/1     Running   0          5m
# dev-netbox-xxxxx              1/1     Running   0          5m

# Check the route
oc get route -n netbox-dev

# Test the API
curl -k https://$(oc get route -n netbox-dev -o jsonpath='{.items[0].spec.host}')/api/
```

## Using the Makefile

Quick commands for common operations:

```bash
# Validate configuration
make validate-dev

# Check status
make status-dev

# View logs
make logs-dev

# Open NetBox shell
make shell-netbox-dev

# Backup database
make backup-dev
```

## Troubleshooting

### Pods not starting?
```bash
# Check events
oc get events -n netbox-dev --sort-by='.lastTimestamp'

# Check pod logs
oc logs -n netbox-dev deployment/dev-netbox
oc logs -n netbox-dev deployment/dev-postgres
oc logs -n netbox-dev deployment/dev-redis
```

### Database connection errors?
```bash
# Verify postgres is running
oc get pods -n netbox-dev -l app=postgres

# Check postgres service
oc get svc -n netbox-dev postgres

# Test connection from netbox pod
oc exec -n netbox-dev deployment/dev-netbox -- \
  nc -zv postgres 5432
```

### ArgoCD sync issues?
```bash
# Check application status
argocd app get netbox-dev

# Force sync
argocd app sync netbox-dev --force

# Refresh
argocd app refresh netbox-dev
```

## Next Steps

1. **Change default passwords** in production
2. **Configure backup schedule** for your database
3. **Set up monitoring** using NetBox's built-in metrics
4. **Install plugins** - see `plugins-example/README.md`
5. **Configure LDAP/SSO** if needed
6. **Set up proper RBAC** for your team

## Common Tasks

### Add a Device
1. Navigate to Devices → Manufacturers → Add
2. Navigate to Devices → Device Types → Add
3. Navigate to Devices → Devices → Add

### Create an IP Prefix
1. Navigate to IPAM → Prefixes → Add
2. Navigate to IPAM → IP Addresses → Add

### Configure Plugins
See `plugins-example/README.md` for detailed instructions.

## Production Deployment

When ready for production:

1. Update `k8s/overlays/prod/kustomization.yaml` with your production settings
2. Apply production secrets securely (use Sealed Secrets or External Secrets Operator)
3. Deploy: `oc apply -f k8s/argocd/netbox-prod.yaml`

## Support

- Full documentation: See `README.md`
- NetBox documentation: https://docs.netbox.dev/
- Report issues: Open an issue in this repository

## Quick Reference

| Command | Description |
|---------|-------------|
| `make validate-dev` | Validate manifests |
| `make deploy-dev` | Deploy to dev |
| `make status-dev` | Check status |
| `make logs-dev` | View logs |
| `make shell-netbox-dev` | Open shell |
| `make backup-dev` | Backup database |

Happy NetBoxing! 🎉
