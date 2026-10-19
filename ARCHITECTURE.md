# Architecture: DevOps Lab with AWS Deployment

This document is your learning map. It explains how the whole system fits
together, from code on your laptop to a running container on AWS. Read it
top to bottom; each diagram zooms into a different layer.

---

## 1. The 10,000-foot view

Three worlds, connected by a pipeline:

```mermaid
flowchart LR
    Dev["Your Laptop<br/>(write code + tests)"]
    GH["GitHub<br/>(stores code + runs pipeline)"]
    AWS["AWS<br/>(runs the app in the cloud)"]

    Dev -->|git push| GH
    GH -->|build, test, package, deploy| AWS
    AWS -->|users open the URL| Users["End Users"]
```

- **Laptop:** where you write and test locally.
- **GitHub:** stores your code and runs the CI/CD pipeline (GitHub Actions).
- **AWS:** where the packaged container actually runs and serves traffic.

---

## 2. The CI/CD pipeline flow

This is what happens automatically on every push to `main`. Each stage is
a gate: if it fails, the stages after it never run.

```mermaid
flowchart TD
    push["Developer pushes to main"] --> test

    subgraph CI["Continuous Integration (prove it's correct)"]
        test["Build + Test<br/>pip install, pytest"]
    end

    subgraph CD["Continuous Delivery/Deployment (ship it)"]
        build["Build Docker image"]
        login["Log in to AWS ECR"]
        pushimg["Push image to ECR"]
        deploy["Update ECS service<br/>(roll out new version)"]
    end

    test -->|tests pass| build
    build --> login --> pushimg --> deploy
    deploy --> healthy["ECS waits until new<br/>containers report healthy"]

    test -.->|tests fail| stop["Pipeline STOPS<br/>nothing ships"]
```

Key idea: **the artifact that gets tested, packaged, and deployed is the
same Docker image.** Build once, run the same thing everywhere.

---

## 3. The AWS runtime architecture (ECR + ECS Fargate)

This is where the container actually runs in the cloud. We use **Fargate**,
which runs containers without you managing any servers (no EC2 to patch).

```mermaid
flowchart TB
    User["End User<br/>(browser)"]

    subgraph AWSCloud["AWS Cloud (one Region)"]
        ECR["ECR<br/>(Elastic Container Registry)<br/>stores Docker images"]

        subgraph VPC["VPC (your private network)"]
            ALB["Application Load Balancer<br/>(public entry point)"]

            subgraph Private["Private Subnets"]
                subgraph ECS["ECS Cluster (Fargate)"]
                    T1["Task 1<br/>(container)"]
                    T2["Task 2<br/>(container)"]
                end
            end
        end

        CW["CloudWatch Logs<br/>(app logs + metrics)"]
    end

    User -->|HTTPS| ALB
    ALB -->|/health check + traffic| T1
    ALB --> T2
    ECR -.->|ECS pulls image| T1
    ECR -.->|ECS pulls image| T2
    T1 -.->|writes logs| CW
    T2 -.->|writes logs| CW
```

### What each piece does

| Component | Role | Why it matters |
|-----------|------|----------------|
| **ECR** | Private Docker image registry | ECS pulls your image from here to run it. |
| **ECS Cluster** | Logical group that runs your tasks | The "where my containers live" boundary. |
| **Fargate** | Serverless compute for containers | You don't manage servers; AWS runs the containers. |
| **Task** | One running copy of your container | Scale out = more tasks. Here we run 2 for redundancy. |
| **Task Definition** | The blueprint for a task | Says which image, CPU/memory, ports, env vars, logs. |
| **Service** | Keeps N tasks running + does rollouts | Restarts crashed tasks, handles deploys. |
| **ALB** | Load balancer / public front door | Spreads traffic across tasks, runs `/health` checks. |
| **VPC + Subnets** | Your isolated network | Tasks live in private subnets; only the ALB is public. |
| **CloudWatch** | Logs and metrics | Where you look when something breaks. |

---

## 4. How a deployment rolls out (zero-downtime)

When the pipeline updates the ECS service with a new image, ECS does a
**rolling update** so users never see downtime:

```mermaid
sequenceDiagram
    participant GH as GitHub Actions
    participant ECS as ECS Service
    participant ALB as Load Balancer
    participant Old as Old Tasks (v1)
    participant New as New Tasks (v2)

    GH->>ECS: Deploy new task definition (v2 image)
    ECS->>New: Start new tasks (v2)
    New->>ALB: Register + pass /health checks
    ALB->>New: Start sending traffic
    ECS->>Old: Drain and stop old tasks (v1)
    Note over ALB,New: Users are now served by v2, no downtime
```

If the new version fails its health checks, ECS can keep the old version
running so a bad deploy doesn't take the app down.

---

## 5. Mapping lab concepts to AWS services

Everything you built locally has a cloud counterpart:

| Lab (local) | AWS (cloud) |
|-------------|-------------|
| `docker build` on your laptop | GitHub Actions builds + pushes to **ECR** |
| `docker compose up` | **ECS Service** running Fargate **Tasks** |
| `localhost:5000` | **ALB** public DNS name (or your domain) |
| `/health` endpoint | **ALB health check** target |
| Terminal output / logs | **CloudWatch Logs** |
| `.venv` + `requirements.txt` | Baked into the **Docker image** |

---

## 6. Security & cost notes (important in the cloud field)

- **Least privilege IAM:** the pipeline's AWS credentials should only be
  allowed to push to ECR and update this one ECS service, nothing more.
- **Secrets:** AWS keys live in **GitHub Secrets**, never in the repo.
  Even better for production: use **OIDC** so GitHub assumes an IAM role
  with no long-lived keys at all.
- **Private subnets:** tasks aren't directly reachable from the internet;
  only the ALB is. This shrinks the attack surface.
- **Cost:** ECS Fargate + ALB are not free-tier-friendly for 24/7 use.
  Expect a small monthly cost (mostly the ALB ~\$16/mo + Fargate usage).
  **Always tear it down after the lab** (see AWS_SETUP.md) to avoid charges.

---

## 7. Where to go deeper

- Swap long-lived AWS keys for **GitHub OIDC** (no stored secrets).
- Add **auto-scaling** so ECS adds tasks under load.
- Add a **custom domain + HTTPS** via Route 53 + ACM certificate.
- Define all of this as code with **Terraform** or **AWS CloudFormation**
  instead of clicking in the console (this is the real DevOps endgame).
```
