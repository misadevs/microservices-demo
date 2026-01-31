# CI/CD Setup Guide for Online Boutique

This guide explains how to configure GitHub Actions for automated deployment of Online Boutique to Google Cloud Platform (GKE).

## Prerequisites

- A Google Cloud Platform account with billing enabled
- A GitHub repository (fork or clone of this project)
- `gcloud` CLI installed locally (for initial setup)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
│                                                                  │
│   Push to main ─────► GitHub Actions Workflow                    │
│                              │                                   │
│                              ▼                                   │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │  1. Validate    │  2. Deploy     │  3. Deploy  │  4. Test │  │
│   │  (Terraform +   │  Infrastructure│  Application│  (Smoke) │  │
│   │   Helm lint)    │  (Terraform)   │  (Helm)     │          │  │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Google Cloud Platform                         │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                   GKE Autopilot Cluster                   │  │
│   │                                                           │  │
│   │  ┌─────────────────────┐  ┌────────────────────────────┐ │  │
│   │  │   Online Boutique   │  │     Monitoring Stack       │ │  │
│   │  │   (11 services)     │  │  (Prometheus + Grafana)    │ │  │
│   │  └─────────────────────┘  └────────────────────────────┘ │  │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your **Project ID** (not the project name)

## Step 2: Enable Required APIs

Run the following commands in Google Cloud Shell or your local terminal:

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable `
    container.googleapis.com `
    compute.googleapis.com `
    cloudresourcemanager.googleapis.com `
    iam.googleapis.com `
    monitoring.googleapis.com `
    cloudtrace.googleapis.com `
    cloudprofiler.googleapis.com
```

## Step 3: Create a Service Account

Create a service account with the necessary permissions for CI/CD:

```bash
# 1. Crear la Service Account
gcloud iam service-accounts create github-actions-sa `
    --display-name="GitHub Actions Service Account"

# 2. Definir el email de la Service Account (PowerShell usa $ para variables)
$SA_EMAIL = "github-actions-sa@$($PROJECT_ID).iam.gserviceaccount.com"

# 3. Asignar roles (puedes copiar y pegar este bloque completo)
gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/monitoring.admin"

# 4. Crear y descargar la llave (Usamos $HOME para la ruta del usuario)
gcloud iam service-accounts keys create "$HOME\sa-key.json" `
    --iam-account=$SA_EMAIL

Write-Host "Service account key saved to $HOME\sa-key.json" -ForegroundColor Green
```

## Step 4: Create Terraform State Bucket

Terraform needs a GCS bucket to store its state file:

```bash
# Create the bucket
gsutil mb -p $PROJECT_ID -l us-central1 gs://${PROJECT_ID}-terraform-state

# Enable versioning for state recovery
gsutil versioning set on gs://${PROJECT_ID}-terraform-state

echo "Terraform state bucket created: gs://${PROJECT_ID}-terraform-state"
```

## Step 5: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

| Secret Name | Description | How to Get It |
|------------|-------------|---------------|
| `GCP_PROJECT_ID` | Your GCP Project ID | From GCP Console or `gcloud config get-value project` |
| `GCP_SA_KEY` | Service Account JSON key | Contents of `~/sa-key.json` file |

### Adding the secrets:

1. **GCP_PROJECT_ID**:
   - Click "New repository secret"
   - Name: `GCP_PROJECT_ID`
   - Value: Your project ID (e.g., `my-project-123`)

2. **GCP_SA_KEY**:
   - Click "New repository secret"
   - Name: `GCP_SA_KEY`
   - Value: Copy the entire contents of `~/sa-key.json`

```bash
# Display the key content to copy
cat ~/sa-key.json
```

## Step 6: Run the Pipeline

### Option A: Automatic Deployment (Push to main)

Simply push changes to the `main` branch:

```bash
git add .
git commit -m "Configure CI/CD pipeline"
git push origin main
```

The workflow will automatically:
1. Validate Terraform and Helm configurations
2. Create/update the GKE cluster
3. Deploy Online Boutique
4. Install Prometheus + Grafana
5. Run smoke tests
6. Output access URLs

### Option B: Manual Deployment

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select "Deploy Online Boutique" workflow
4. Click "Run workflow"
5. Select environment and click "Run workflow"

## Step 7: Access Your Deployment

After the pipeline completes successfully, check the workflow summary for access URLs:

- **Online Boutique**: `http://<FRONTEND_IP>`
- **Grafana Dashboard**: `http://<GRAFANA_IP>`
  - Username: `admin`
  - Password: `admin123`

### Local Access via Port Forward

```bash
# Get cluster credentials
gcloud container clusters get-credentials online-boutique \
    --region us-central1 \
    --project $PROJECT_ID

# Access Grafana locally
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Open: http://localhost:3000

# Access Prometheus locally
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090
```

## Destroying Infrastructure

To avoid ongoing costs, destroy the infrastructure when not needed:

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select "Destroy Infrastructure" workflow
4. Click "Run workflow"
5. Type `destroy` in the confirmation field
6. Optionally check "Also delete Terraform state bucket"
7. Click "Run workflow"

## Estimated Costs

| Resource | Estimated Cost |
|----------|---------------|
| GKE Autopilot | ~$0.10/hour (scales with usage) |
| Load Balancers (2) | ~$0.025/hour each |
| Network Egress | Variable |

**Tip**: Always destroy infrastructure when not actively using it.

## Troubleshooting

### Pipeline fails at Terraform Init

- Verify `GCP_SA_KEY` secret is correctly formatted (entire JSON content)
- Verify Terraform state bucket exists: `gsutil ls gs://${PROJECT_ID}-terraform-state`

### Pipeline fails at GKE creation

- Check if APIs are enabled
- Verify service account has `roles/container.admin` role
- Check GCP quotas for your region

### Pods not becoming ready

- Check pod logs: `kubectl logs -l app=<service-name>`
- Check events: `kubectl get events --sort-by='.lastTimestamp'`

### Cannot access frontend

- Verify LoadBalancer has external IP: `kubectl get svc frontend-external`
- Check firewall rules in GCP Console

## Workflow Files

| File | Purpose |
|------|---------|
| `.github/workflows/deploy-online-boutique.yaml` | Main deployment workflow |
| `.github/workflows/destroy-infrastructure.yaml` | Infrastructure destruction workflow |
| `terraform/backend.tf` | Terraform GCS backend configuration |
| `helm-chart/values-production.yaml` | Production Helm values |

## Security Notes

- The service account key (`GCP_SA_KEY`) has broad permissions. Keep it secure.
- Consider using [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) for keyless authentication in production.
- The default Grafana password should be changed after first login.
- Network policies are enabled in production to limit pod-to-pod communication.
