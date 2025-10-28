.PHONY: help validate-dev validate-prod deploy-dev deploy-prod sync-dev sync-prod logs-dev logs-prod shell-netbox shell-postgres backup-dev backup-prod

help:
	@echo "NetBox OpenShift Deployment - Available targets:"
	@echo ""
	@echo "  Validation:"
	@echo "    validate-dev          Validate dev kustomization"
	@echo "    validate-prod         Validate prod kustomization"
	@echo ""
	@echo "  Deployment:"
	@echo "    deploy-argocd         Deploy ArgoCD applications"
	@echo "    deploy-dev            Deploy directly to dev (without ArgoCD)"
	@echo "    deploy-prod           Deploy directly to prod (without ArgoCD)"
	@echo ""
	@echo "  ArgoCD:"
	@echo "    sync-dev              Sync dev application in ArgoCD"
	@echo "    sync-prod             Sync prod application in ArgoCD"
	@echo ""
	@echo "  Monitoring:"
	@echo "    logs-dev              Show NetBox logs (dev)"
	@echo "    logs-prod             Show NetBox logs (prod)"
	@echo "    status-dev            Show status of dev resources"
	@echo "    status-prod           Show status of prod resources"
	@echo ""
	@echo "  Maintenance:"
	@echo "    shell-netbox-dev      Open shell in NetBox pod (dev)"
	@echo "    shell-postgres-dev    Open shell in PostgreSQL pod (dev)"
	@echo "    backup-dev            Backup dev database"
	@echo "    backup-prod           Backup prod database"
	@echo "    migrate-dev           Run database migrations (dev)"
	@echo "    migrate-prod          Run database migrations (prod)"

validate-dev:
	@echo "Validating dev environment kustomization..."
	kustomize build k8s/overlays/dev

validate-prod:
	@echo "Validating prod environment kustomization..."
	kustomize build k8s/overlays/prod

deploy-argocd:
	@echo "Deploying ArgoCD applications..."
	oc apply -f k8s/argocd/

deploy-dev:
	@echo "Deploying to dev environment..."
	oc apply -k k8s/overlays/dev

deploy-prod:
	@echo "Deploying to prod environment..."
	oc apply -k k8s/overlays/prod

sync-dev:
	@echo "Syncing dev application..."
	argocd app sync netbox-dev

sync-prod:
	@echo "Syncing prod application..."
	argocd app sync netbox-prod

logs-dev:
	@echo "Following NetBox logs (dev)..."
	oc logs -f -n netbox-dev -l app=netbox

logs-prod:
	@echo "Following NetBox logs (prod)..."
	oc logs -f -n netbox-prod -l app=netbox

status-dev:
	@echo "Dev environment status:"
	@echo "\nPods:"
	oc get pods -n netbox-dev
	@echo "\nServices:"
	oc get svc -n netbox-dev
	@echo "\nRoutes:"
	oc get route -n netbox-dev

status-prod:
	@echo "Prod environment status:"
	@echo "\nPods:"
	oc get pods -n netbox-prod
	@echo "\nServices:"
	oc get svc -n netbox-prod
	@echo "\nRoutes:"
	oc get route -n netbox-prod

shell-netbox-dev:
	@echo "Opening shell in NetBox pod (dev)..."
	oc exec -it -n netbox-dev deployment/dev-netbox -- /bin/bash

shell-postgres-dev:
	@echo "Opening PostgreSQL shell (dev)..."
	oc exec -it -n netbox-dev deployment/dev-postgres -- psql -U netbox netbox

backup-dev:
	@echo "Backing up dev database..."
	@mkdir -p backups
	oc exec -n netbox-dev deployment/dev-postgres -- pg_dump -U netbox netbox > backups/netbox-dev-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Backup saved to backups/"

backup-prod:
	@echo "Backing up prod database..."
	@mkdir -p backups
	oc exec -n netbox-prod deployment/prod-postgres -- pg_dump -U netbox netbox > backups/netbox-prod-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Backup saved to backups/"

migrate-dev:
	@echo "Running database migrations (dev)..."
	oc exec -n netbox-dev deployment/dev-netbox -- python3 /opt/netbox/netbox/manage.py migrate

migrate-prod:
	@echo "Running database migrations (prod)..."
	oc exec -n netbox-prod deployment/prod-netbox -- python3 /opt/netbox/netbox/manage.py migrate
