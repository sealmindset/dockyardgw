# Dockyard Gateway -- Roadshow Deck

> Use this document as talking points for presenting Dockyard Gateway to engineering teams, leadership, and stakeholders. Written for a mixed audience -- no deep container knowledge assumed.

---

## The Elevator Pitch (30 seconds)

Dockyard Gateway is a secure, company-managed container image gateway that lets every developer pull Docker images without disabling Zscaler, automatically scans every image for vulnerabilities before anyone can use it, and gives Security Engineering full visibility into what images are running across the company.

---

## What Problem Does This Solve?

### The Zscaler Problem

Every developer has hit this:

```
$ docker pull python:3.12-slim
Error response from daemon: Get "https://registry-1.docker.io/v2/":
x509: certificate signed by unknown authority
```

**Why it happens:** Zscaler (our SSL-inspecting proxy) sits between your laptop and Docker Hub. Docker doesn't trust Zscaler's certificate, so every pull fails.

**The old workaround:** Pause Zscaler, pull the image, re-enable Zscaler. This creates a window where your laptop is unprotected -- and it's easy to forget to turn it back on.

**The Dockyard Gateway fix:** Pull images from our own Azure Container Registry instead. The registry fetches from Docker Hub/MCR/GHCR server-side in Azure -- Zscaler never touches it.

```
# Before (broken)
docker pull python:3.12-slim

# After (works every time, no Zscaler issues)
docker pull dockyardgwprod.azurecr.io/docker.io/library/python:3.12-slim
```

### The Visibility Problem

Today, nobody knows:
- What container images are being used across the company
- Whether those images have known vulnerabilities
- Who is pulling what, and when

Dockyard Gateway logs every pull, scans every image, and enforces security policy -- automatically.

---

## What Is It, Exactly?

Dockyard Gateway is an **Azure Container Registry (Premium)** configured as a **proxy cache** with **security scanning and policy enforcement** layered on top.

Think of it like a library:
- **Docker Hub, MCR, GHCR** are bookstores (public sources of images)
- **Dockyard Gateway** is your company library -- it orders books from the stores, checks them for problems, catalogs them, and makes them available to everyone on the network

### Components

| Component | What It Does |
|-----------|-------------|
| **Azure Container Registry (Premium)** | Stores and serves container images. Caches images from upstream registries so they only need to be fetched once. |
| **Proxy Cache Rules** | Automatically fetch images from Docker Hub, MCR, and GHCR when someone requests them. No manual import needed. |
| **Microsoft Defender for Containers** | Scans every image for known vulnerabilities (CVEs) as soon as it enters the registry. |
| **Azure Policy** | Blocks images with Critical or High vulnerabilities. Quarantines images with Medium or Low findings for admin review. |
| **RBAC (Role-Based Access)** | Controls who can pull images (everyone) and who can push/approve images (Security Engineering). |
| **Log Analytics + Alerts** | Tracks every operation. Alerts Security Engineering when images are blocked. |

---

## "Don't We Already Have a Container Registry?"

You might. Here's how Dockyard Gateway is different:

| Feature | Typical ACR | Dockyard Gateway |
|---------|------------|-----------------|
| Store images | Yes | Yes |
| Proxy cache (pull-through from Docker Hub/MCR/GHCR) | No (manual push only) | Yes (automatic) |
| Automatic vulnerability scanning | Maybe (if Defender is enabled) | Yes (mandatory, built in) |
| Block vulnerable images by policy | No | Yes (Critical/High blocked, Medium/Low quarantined) |
| Works through Zscaler | Same problem | Solved (server-side fetch) |
| Company-wide access controls | Varies | Yes (Azure AD groups, everyone can pull) |
| Audit trail of all image usage | Varies | Yes (Log Analytics, 90-day retention) |
| Alerting on blocked images | No | Yes (email alerts to Security Engineering) |

If your team already has an ACR for storing your own application images, that's fine -- Dockyard Gateway doesn't replace it. Dockyard Gateway is specifically for **pulling public/upstream images safely**. Your team's ACR is for your **private application images**.

---

## What Are MCR and GHCR? Why Do We Need to Cache Them?

### The Three Major Public Registries

| Registry | Full Name | What's In It | Examples |
|----------|-----------|-------------|---------|
| **Docker Hub** (`docker.io`) | Docker Hub | The largest public registry. Official images for languages, databases, tools. | `python:3.12`, `postgres:16`, `nginx:latest`, `node:22` |
| **MCR** (`mcr.microsoft.com`) | Microsoft Container Registry | Microsoft's official images for Azure, .NET, SQL Server, dev tools. | `azure-cli`, `dotnet/sdk`, `mssql/server`, `devcontainers/python` |
| **GHCR** (`ghcr.io`) | GitHub Container Registry | Images published by GitHub projects and GitHub Actions. | `actions/actions-runner`, community project images |

### Why Cache Them?

1. **Zscaler compatibility** -- pulling from Azure-to-Azure bypasses SSL inspection
2. **Speed** -- cached images are served from our Azure region, not pulled from the internet every time
3. **Rate limits** -- Docker Hub limits anonymous pulls to 100/6 hours. One cached copy serves the whole company.
4. **Security scanning** -- every image is scanned before anyone can use it
5. **Audit trail** -- we know exactly what images are in use

---

## How Secure Is It?

### Defense in Depth

```
Layer 1: Authentication
  Every pull requires Azure AD login -- no anonymous access

Layer 2: Automatic Scanning
  Microsoft Defender scans every image for known CVEs
  within minutes of it entering the registry

Layer 3: Policy Enforcement
  Critical/High vulnerabilities → BLOCKED (image cannot be pulled)
  Medium/Low vulnerabilities → QUARANTINED (admin must approve)
  Clean images → AVAILABLE immediately

Layer 4: Access Control
  Everyone can pull (AcrPull via Azure AD group)
  Only Security Engineering can push or approve (AcrPush)

Layer 5: Audit Trail
  Every pull, push, login, and policy action is logged
  90-day retention in Log Analytics
  Alerts on blocked images
```

### What Happens When a Vulnerable Image Is Found?

```
Developer pulls python:3.12-slim
        |
        v
ACR fetches from Docker Hub (server-side)
        |
        v
Defender scans the image
        |
        +-- Clean? → Available immediately
        |
        +-- Medium/Low CVEs? → Quarantined
        |     Admin reviews → Approve or Reject
        |
        +-- Critical/High CVEs? → Blocked
              Cannot be pulled by anyone
              Alert sent to Security Engineering
```

---

## How Do We Know We Can Trust the Images?

**Short answer:** You trust the same upstream sources you already use (Docker Hub, Microsoft, GitHub) -- but now every image is verified by Defender before you can use it.

**Longer answer:**

| Trust Layer | How It Works |
|-------------|-------------|
| **Source integrity** | Images come from the same official registries (Docker Hub, MCR, GHCR) your team already uses. Dockyard Gateway doesn't modify them. |
| **Vulnerability scanning** | Microsoft Defender for Containers scans every image against the National Vulnerability Database (NVD) and Microsoft's own threat intelligence. |
| **Policy enforcement** | Even if an image was safe last week, if a new CVE is discovered, Defender re-scans and Policy blocks it automatically. |
| **No anonymous access** | Every pull is authenticated via Azure AD. You can't pull without being a company employee. |
| **Immutable cache** | Only the proxy cache can write upstream images. No developer can push a modified image into the cache namespace. |
| **Audit trail** | If something goes wrong, we can trace exactly who pulled what image, when, and from which source. |

**What Dockyard Gateway does NOT do:**
- It doesn't guarantee images are free of all bugs (no tool can)
- It doesn't scan for malicious intent or backdoors in source code (it scans for known CVEs)
- It doesn't replace your team's responsibility to use official, maintained images

**What it DOES guarantee:**
- No image with a known Critical or High vulnerability can be used
- Every image is scanned before it reaches any developer
- There's a complete audit trail of all image usage

---

## How Do I Use It?

### One-Time Setup (2 minutes)

```bash
# 1. Login to the registry (uses your Azure AD credentials)
az acr login --name dockyardgwprod

# That's it. You're ready to pull images.
```

### Daily Usage

Just add `dockyardgwprod.azurecr.io/` in front of the image name:

```bash
# Docker Hub official images
docker pull dockyardgwprod.azurecr.io/docker.io/library/python:3.12-slim
docker pull dockyardgwprod.azurecr.io/docker.io/library/postgres:16
docker pull dockyardgwprod.azurecr.io/docker.io/library/node:22-alpine

# Docker Hub community images
docker pull dockyardgwprod.azurecr.io/docker.io/grafana/grafana:latest

# Microsoft images
docker pull dockyardgwprod.azurecr.io/mcr.microsoft.com/azure-cli:latest
docker pull dockyardgwprod.azurecr.io/mcr.microsoft.com/dotnet/sdk:8.0

# GitHub Container Registry images
docker pull dockyardgwprod.azurecr.io/ghcr.io/actions/actions-runner:latest
```

### In Dockerfiles

```dockerfile
# Before
FROM python:3.12-slim

# After
FROM dockyardgwprod.azurecr.io/docker.io/library/python:3.12-slim
```

### In docker-compose.yml

```yaml
services:
  db:
    image: dockyardgwprod.azurecr.io/docker.io/library/postgres:16
  app:
    build:
      context: .
      # Dockerfile uses the gateway image as base
```

### Tips
- **First pull** of a new image may take a moment (ACR is fetching from upstream). Subsequent pulls are instant (cached).
- **You don't need to disable Zscaler.** That's the whole point.
- **Your Azure AD login** is cached by Docker for several hours. You don't need to `az acr login` before every pull.

---

## FAQ

### "Can I still pull directly from Docker Hub?"
You can try, but Zscaler will likely block it. Dockyard Gateway is the supported path.

### "What if the image I need isn't cached yet?"
Just pull it. The proxy cache fetches on demand -- the first pull triggers the fetch. You don't need to request images be added.

### "What if my image gets quarantined?"
Contact Security Engineering. They'll review the vulnerability findings and either approve the image or recommend an alternative version that's clean.

### "Does this slow down my builds?"
First pull of a new image: similar speed to pulling from the internet (ACR fetches upstream). Every pull after that: faster, because it's served from Azure in our region.

### "Do I need to change all my Dockerfiles?"
For images you pull regularly, yes -- update the `FROM` line. For CI/CD pipelines, your DevOps team can configure the registry prefix centrally.

### "What about private images my team builds?"
Dockyard Gateway is for public/upstream images only. Your team's private images stay in your team's own ACR (if you have one) or can be pushed to Dockyard Gateway's non-cached namespaces by Security Engineering.

### "Who manages this?"
Security Engineering owns Dockyard Gateway. For questions, issues, or image approvals, reach out to the Security Engineering team.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Developer Laptop                             │
│                                                                  │
│  docker pull dockyardgwprod.azurecr.io/docker.io/library/python │
│         |                                                        │
│         v                                                        │
│  ┌─────────────┐     Zscaler doesn't interfere                  │
│  │ Azure AD     │     (Azure-to-Azure traffic)                   │
│  │ Login        │                                                │
│  └──────┬──────┘                                                 │
└─────────┼───────────────────────────────────────────────────────┘
          |
          v
┌─────────────────────────── Azure Cloud ─────────────────────────┐
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           Dockyard Gateway (dockyardgwprod)               │   │
│  │           Azure Container Registry (Premium)              │   │
│  │                                                           │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │   │
│  │  │ Proxy Cache  │  │   Defender    │  │  Azure Policy   │  │   │
│  │  │             │  │   Scanning    │  │                 │  │   │
│  │  │ Fetches     │  │              │  │  Critical/High  │  │   │
│  │  │ from        │  │  Checks for  │  │  → BLOCKED      │  │   │
│  │  │ upstream    │  │  known CVEs  │  │                 │  │   │
│  │  │ on first    │  │  on every    │  │  Medium/Low     │  │   │
│  │  │ pull        │  │  image       │  │  → QUARANTINED  │  │   │
│  │  └──────┬──────┘  └──────────────┘  └────────────────┘  │   │
│  │         |                                                │   │
│  │  ┌──────┴──────────────────────────────┐                 │   │
│  │  │         Cached Image Store           │                 │   │
│  │  │  python:3.12  postgres:16  node:22  │                 │   │
│  │  │  azure-cli    dotnet/sdk   ...      │                 │   │
│  │  └─────────────────────────────────────┘                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│         |              |              |                           │
│         v              v              v                           │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐                  │
│  │ Docker Hub  │ │    MCR     │ │   GHCR     │                  │
│  │ docker.io   │ │ mcr.msft   │ │ ghcr.io    │                  │
│  └────────────┘ └────────────┘ └────────────┘                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Log Analytics          │  Alerts                         │   │
│  │  Every pull logged      │  Email on blocked images        │   │
│  │  90-day retention       │  Security Engineering notified  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  RBAC (Azure AD)                                          │   │
│  │  AcrPull: All Employees (everyone can pull)               │   │
│  │  AcrPush: Security Engineering (admin only)               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Key Metrics (Post-Deployment)

Track these to demonstrate value:

| Metric | Where to Find It | What It Shows |
|--------|-----------------|---------------|
| Total image pulls | Log Analytics | Adoption across the company |
| Unique images cached | `az acr repository list` | Breadth of usage |
| Vulnerable images blocked | Policy compliance reports | Security posture improvement |
| Images quarantined + approved | Admin approval logs | Security review activity |
| Zscaler-related support tickets | IT helpdesk | Should decrease to near-zero |
| Docker Hub rate limit hits | Should be zero | Cost avoidance + reliability |

---

## Rollout Plan

| Phase | Audience | Goal |
|-------|----------|------|
| **Phase 1: Pilot** | Security Engineering + 1-2 dev teams | Validate proxy cache, scanning, and approval workflow |
| **Phase 2: Engineering** | All engineering teams | Update Dockerfiles and CI/CD pipelines |
| **Phase 3: Company-wide** | Everyone with Docker | Default image source for all container workloads |

---

*Owned by Security Engineering | Questions? Reach out to the Security Engineering team.*
