# GitLab CI/CD Pipeline Documentation

This document describes the GitLab CI/CD pipeline for building, scanning, and pushing the NetBox custom Docker image.

## Pipeline Overview

The pipeline consists of 4 stages:

1. **Lint** - Code quality and syntax validation
2. **Build** - Docker image building
3. **Scan** - Security vulnerability scanning
4. **Push** - Push images to container registry

## Pipeline Stages

### 1. Lint Stage

#### dockerfile-lint
- **Tool**: Hadolint
- **Purpose**: Validates Dockerfile best practices and syntax
- **Failure**: Pipeline fails if Dockerfile has issues
- **Configuration**: `.hadolint.yaml`

#### yaml-lint
- **Tool**: yamllint
- **Purpose**: Validates YAML syntax in Kubernetes manifests
- **Failure**: Allowed to fail (warnings only)
- **Configuration**: `.yamllint`

### 2. Build Stage

#### build-image
- **Tool**: Docker
- **Purpose**: Builds the custom NetBox image
- **Output**: Saves image as artifact (`image.tar`)
- **Tags created**:
  - `$IMAGE_NAME:$CI_COMMIT_SHORT_SHA` - Commit SHA
  - `$IMAGE_NAME:$CI_COMMIT_REF_SLUG` - Branch name

**Build Arguments**:
- `BUILD_DATE` - Timestamp of the build
- `VCS_REF` - Git commit SHA
- `VERSION` - Git tag or commit SHA

**Labels**:
- `org.opencontainers.image.created`
- `org.opencontainers.image.revision`
- `org.opencontainers.image.version`

### 3. Scan Stage

#### trivy-scan
- **Tool**: Trivy (Aqua Security)
- **Purpose**: Scans for OS and application vulnerabilities
- **Severity**: Checks for HIGH and CRITICAL vulnerabilities
- **Reports**: JSON format for GitLab integration
- **Failure**: Warns on critical vulnerabilities but allows continuation

#### dependency-scan
- **Tools**: Safety + pip-audit
- **Purpose**: Scans Python dependencies for known vulnerabilities
- **Target**: `plugins-example/requirements.txt`
- **Reports**: JSON format
- **Failure**: Allowed to fail (warnings only)

#### grype-scan
- **Tool**: Grype (Anchore)
- **Purpose**: Alternative vulnerability scanner
- **Severity**: Fails on critical vulnerabilities
- **Reports**: JSON and table format
- **Failure**: Allowed to fail (warnings only)

### 4. Push Stage

#### push-image
- **Purpose**: Pushes images to GitLab Container Registry
- **Runs on**: main, develop branches, or git tags
- **Tags pushed**:
  - `$IMAGE_TAG` - Commit SHA (always)
  - `$CI_COMMIT_REF_SLUG` - Branch name (always)
  - `latest` - Only for main/master branch
  - Version tag - Only when building a git tag

## Prerequisites

### GitLab Runner Requirements

1. **Docker executor** with privileged mode enabled
2. **Tags**: Runners must have the `docker` tag

### GitLab CI/CD Variables

The following variables are automatically provided by GitLab:
- `CI_REGISTRY` - GitLab container registry URL
- `CI_REGISTRY_IMAGE` - Full image path
- `CI_REGISTRY_USER` - GitLab username
- `CI_REGISTRY_PASSWORD` - GitLab registry password
- `CI_COMMIT_SHORT_SHA` - Short commit SHA
- `CI_COMMIT_SHA` - Full commit SHA
- `CI_COMMIT_REF_SLUG` - Branch/tag name (sanitized)
- `CI_COMMIT_BRANCH` - Current branch
- `CI_COMMIT_TAG` - Git tag (if tagged)

No additional variables need to be configured for basic operation.

## Setup Instructions

### 1. Enable GitLab Container Registry

Ensure the GitLab Container Registry is enabled for your project:
- Go to **Settings > General > Visibility**
- Enable **Container Registry**

### 2. Configure GitLab Runner

Add a runner with Docker executor:

```yaml
# /etc/gitlab-runner/config.toml
[[runners]]
  name = "docker-runner"
  executor = "docker"
  [runners.docker]
    privileged = true
    image = "docker:24"
    volumes = ["/certs/client", "/cache"]
  [runners.cache]
    Type = "volume"
```

Tag the runner with `docker`:
```bash
gitlab-runner register --tag-list docker
```

### 3. Push Code to GitLab

```bash
git add .gitlab-ci.yml
git commit -m "Add GitLab CI/CD pipeline"
git push origin main
```

The pipeline will automatically start.

## Using the Pipeline

### Automatic Triggers

The pipeline runs automatically on:
- **Push to any branch** - Runs lint, build, and scan
- **Push to main/develop** - Also pushes images
- **Git tags** - Pushes versioned images

### Manual Testing

Test the pipeline locally with `gitlab-runner`:

```bash
# Lint Dockerfile
docker run --rm -i hadolint/hadolint < Dockerfile

# Build image locally
docker build -t netbox-custom:test .

# Scan with Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image netbox-custom:test
```

### Viewing Results

1. **Pipeline Overview**: Go to **CI/CD > Pipelines**
2. **Job Logs**: Click on individual jobs to view logs
3. **Security Reports**: Go to **Security & Compliance > Vulnerability Report**
4. **Artifacts**: Download scan reports from job artifacts

## Image Tags Strategy

### Development Workflow

```bash
# Feature branch
feature/add-plugin → netbox:feature-add-plugin

# Development branch
develop → netbox:develop, netbox:<sha>

# Main branch
main → netbox:latest, netbox:main, netbox:<sha>

# Git tags
v1.0.0 → netbox:v1.0.0, netbox:<sha>
```

### Using Images in Deployments

```yaml
# Use specific SHA (immutable)
image: $CI_REGISTRY_IMAGE:abc123

# Use branch tag (updates with branch)
image: $CI_REGISTRY_IMAGE:develop

# Use version tag (production)
image: $CI_REGISTRY_IMAGE:v1.0.0
```

## Troubleshooting

### Pipeline Fails on Dockerfile Lint

Check Hadolint errors:
```bash
docker run --rm -i hadolint/hadolint < Dockerfile
```

Common issues:
- Missing `--no-cache-dir` with pip install
- Using `latest` tag
- Missing user specification

### Build Stage Fails

1. **Check Dockerfile syntax**:
   ```bash
   docker build --no-cache .
   ```

2. **Check plugin requirements**:
   ```bash
   cat plugins-example/requirements.txt
   ```

3. **Review base image**:
   ```bash
   docker pull netboxcommunity/netbox:latest
   ```

### Scan Stage Shows Vulnerabilities

1. **Review the report**: Download `trivy-report.json` from artifacts
2. **Update base image**: Wait for NetBox community to update
3. **Suppress false positives**: Use `.trivyignore` file

Create `.trivyignore`:
```
# Suppress specific CVEs
CVE-2023-12345
```

### Push Stage Fails

1. **Check registry permissions**:
   ```bash
   docker login $CI_REGISTRY
   ```

2. **Verify runner can access registry**:
   - Check network connectivity
   - Verify SSL certificates

3. **Check storage quota**:
   - Go to **Settings > Usage Quotas**
   - Clean up old images

## Security Scanning Details

### Trivy Configuration

Customize scanning by adding `.trivyignore`:

```
# Ignore specific vulnerabilities
CVE-2023-12345

# Ignore by package
pkg:pypi/requests@2.28.0
```

### Safety Configuration

Customize Python scanning with `.safety-policy.yml`:

```yaml
security:
  ignore-cvss-severity-below: 7.0
  ignore-vulnerabilities:
    12345: reason for ignoring
```

## Optimization Tips

### Faster Builds

1. **Use layer caching**:
   ```dockerfile
   # Copy requirements first
   COPY requirements.txt /tmp/
   RUN pip install -r /tmp/requirements.txt

   # Copy code later
   COPY . /app/
   ```

2. **Multi-stage builds**:
   ```dockerfile
   FROM python:3.11 AS builder
   # Build dependencies

   FROM netboxcommunity/netbox:latest
   COPY --from=builder /deps /deps
   ```

### Reduce Scan Time

Run scans in parallel:
```yaml
trivy-scan:
  parallel:
    matrix:
      - SCANNER: [trivy, grype]
```

### Clean Up Old Images

Add cleanup job:
```yaml
cleanup-registry:
  stage: cleanup
  script:
    - # Delete images older than 30 days
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
```

## CI/CD Best Practices

1. **Pin base image versions**: Use specific tags instead of `latest`
2. **Sign images**: Use `cosign` for image signing
3. **SBOM generation**: Generate Software Bill of Materials
4. **Run security scans regularly**: Schedule nightly scans
5. **Keep runners updated**: Update GitLab Runner regularly
6. **Use cache wisely**: Cache dependencies, not build artifacts
7. **Monitor pipeline performance**: Track build times and optimize

## Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Hadolint Rules](https://github.com/hadolint/hadolint#rules)
