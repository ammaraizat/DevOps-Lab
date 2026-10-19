# AWS Setup Guide (ECR + ECS Fargate)

This is the one-time setup to make the pipeline's `deploy-aws` job ship
your container to AWS for real. Follow it once; after that, every push to
`main` deploys automatically.

> ⚠️ **Cost warning:** ECS Fargate + an Application Load Balancer are NOT
> free-tier friendly for 24/7 use. Expect a small monthly cost (the ALB
> alone is roughly \$16/month, plus Fargate runtime). **Do the cleanup
> step at the end when you're done learning.**

---

## Prerequisites

- An AWS account.
- The AWS CLI installed and configured (`aws configure`) with admin-ish
  access for this setup. (Verify with `aws sts get-caller-identity`.)
- Your app already pushed to a GitHub repo.

Set some shell variables first (adjust region as you like):

```bash
export AWS_REGION=us-east-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REPO=devops-lab
export CLUSTER=devops-lab-cluster
export SERVICE=devops-lab-service
```

---

## Step 1 — Create the ECR repository (image registry)

```bash
aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION"
```

This is where the pipeline pushes your Docker images.

---

## Step 2 — Create the CloudWatch log group

The task definition logs to `/ecs/devops-lab`, so create it:

```bash
aws logs create-log-group --log-group-name "/ecs/devops-lab" --region "$AWS_REGION"
```

---

## Step 3 — Create IAM roles

### a) Task execution role (lets ECS pull images + write logs)

```bash
aws iam create-role --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### b) Task role (permissions your app code needs — none here)

```bash
aws iam create-role --role-name ecsTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'
```

Now edit `aws/task-definition.json` and replace `<ACCOUNT_ID>` and
`<REGION>` with your real values.

---

## Step 4 — Create the ECS cluster, ALB, and service

This is the biggest step. The easiest reliable path for a beginner is the
**AWS Console → ECS → Create cluster**, then **Create service** with:

- Launch type: **Fargate**
- Task definition: register `aws/task-definition.json` first (Step 5), then pick it
- Desired tasks: **2**
- Networking: a VPC with public + private subnets
- Load balancing: **Application Load Balancer**, new target group,
  health check path **`/health`**, port **5000**

The console wizard creates the VPC wiring, target group, and security
groups for you, which is why it's recommended over hand-rolling the CLI
for your first time.

> For a fully reproducible setup, the professional approach is to define
> all of this with **Terraform** or **CloudFormation** instead of the
> console. That's the recommended next step once this works.

---

## Step 5 — Register the first task definition

```bash
aws ecs register-task-definition \
  --cli-input-json file://aws/task-definition.json \
  --region "$AWS_REGION"
```

After this, the pipeline handles all future revisions automatically.

---

## Step 6 — Create an IAM user for the pipeline (least privilege)

The pipeline needs AWS credentials. Create a dedicated user whose
permissions are limited to pushing to ECR and updating this ECS service.

```bash
aws iam create-user --user-name github-actions-deployer
aws iam create-access-key --user-name github-actions-deployer
```

Attach a least-privilege policy (ECR push + ECS update + pass the two
roles). Avoid `AdministratorAccess` for a deploy user. Save the
AccessKeyId and SecretAccessKey from the output; you'll paste them into
GitHub next.

> **Better than keys:** GitHub OIDC lets Actions assume an IAM role with
> no long-lived secrets at all. Once comfortable, switch to that.

---

## Step 7 — Add secrets and variables to GitHub

In your repo: **Settings → Secrets and variables → Actions**.

**Secrets** (encrypted):

| Name | Value |
|------|-------|
| `AWS_ACCESS_KEY_ID` | from Step 6 |
| `AWS_SECRET_ACCESS_KEY` | from Step 6 |

**Variables** (plain, non-secret):

| Name | Example |
|------|---------|
| `AWS_REGION` | `us-east-1` |
| `ECR_REPOSITORY` | `devops-lab` |
| `ECS_CLUSTER` | `devops-lab-cluster` |
| `ECS_SERVICE` | `devops-lab-service` |
| `ECS_CONTAINER_NAME` | `web` |

The pipeline's `deploy-aws` job activates automatically once `AWS_REGION`
is set. If it's empty, the `deploy-simulated` job runs instead.

---

## Step 8 — Push and watch it deploy

```bash
git add .
git commit -m "Enable AWS ECS deployment"
git push origin main
```

Open the repo's **Actions** tab. You'll see: build-and-test →
docker-build → **deploy-aws**. When it finishes, grab your ALB's DNS name
from the EC2 Console (Load Balancers) and open it in a browser. You should
see the app's `/` greeting, now served from AWS.

---

## Step 9 — CLEAN UP (do this to stop charges)

```bash
# Scale the service to 0, then delete it
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --desired-count 0 --region "$AWS_REGION"
aws ecs delete-service --cluster "$CLUSTER" --service "$SERVICE" --force --region "$AWS_REGION"

# Delete the cluster
aws ecs delete-cluster --cluster "$CLUSTER" --region "$AWS_REGION"

# Delete the ECR repo (and its images)
aws ecr delete-repository --repository-name "$REPO" --force --region "$AWS_REGION"

# Delete the log group
aws logs delete-log-group --log-group-name "/ecs/devops-lab" --region "$AWS_REGION"
```

Also delete the **Application Load Balancer** and its **target group** in
the EC2 Console (these are the main ongoing cost), plus the IAM user and
roles you created. Double-check the Billing dashboard a day later.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Tasks keep restarting | App crashing — check **CloudWatch Logs** `/ecs/devops-lab`. |
| ALB shows 503 | No healthy targets — health check path/port wrong, or tasks not up. |
| Pipeline "deploy-aws" skipped | `AWS_REGION` variable not set in GitHub. |
| ECR push denied | IAM user missing ECR permissions, or wrong region. |
| Service never stabilizes | Task failing health checks; check `/health` and security groups. |
