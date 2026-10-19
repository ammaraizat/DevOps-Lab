# Terraform: AWS Infrastructure as Code

This folder provisions the **entire** AWS runtime for the lab with a few
commands, instead of clicking through the console. This is the real
DevOps approach: your infrastructure is version-controlled, reviewable,
and reproducible.

## What it creates

| File | Resources |
|------|-----------|
| `versions.tf` | Terraform + AWS provider pinning, default tags. |
| `variables.tf` | Tunable inputs (region, sizing, image tag). |
| `network.tf` | VPC, 2 public + 2 private subnets, IGW, NAT, routes. |
| `ecr.tf` | ECR repository (image registry) + CloudWatch log group. |
| `iam.tf` | ECS task execution role + task role. |
| `alb.tf` | Load balancer, listener, target group, security groups. |
| `ecs.tf` | ECS Fargate cluster, task definition, service. |
| `outputs.tf` | App URL, ECR URL, and the GitHub variable values. |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- AWS CLI configured (`aws configure`); verify with
  `aws sts get-caller-identity`

## Usage

```bash
# from the terraform/ folder
cp terraform.tfvars.example terraform.tfvars   # then edit if you like

terraform init      # download the AWS provider
terraform plan      # preview what will be created (no changes yet)
terraform apply     # create everything (type 'yes' to confirm)
```

> On the first `apply` the ECR repo is empty, so ECS has no image to run
> yet. Tasks will fail to start until the pipeline pushes an image. That
> is expected. Once you push to `main` with the GitHub variables set
> (see below), the service pulls the image and goes healthy.

After `apply`, Terraform prints outputs. Use them:

```bash
terraform output app_url                  # open this in a browser
terraform output github_actions_variables # paste into GitHub repo vars
```

## How this connects to the CI/CD pipeline

Terraform and the pipeline have **separate, non-overlapping jobs**:

- **Terraform owns the infrastructure** — the VPC, ALB, cluster, roles.
  You change these by editing `.tf` files and running `terraform apply`.
- **The pipeline owns the running image** — on every push to `main` it
  builds, pushes to ECR, and updates the ECS service to the new image.

That's why `ecs.tf` has `ignore_changes = [task_definition]`: it stops
Terraform from reverting the image that the pipeline deployed. This clean
split is a common, robust pattern.

### Wiring them together
1. `terraform apply` to build the infrastructure.
2. `terraform output github_actions_variables` and set those as GitHub
   repo **Variables**; set your AWS keys as **Secrets**.
3. Push to `main`. The pipeline deploys the image onto this infra.

## Cost and cleanup

This stack costs real money while it runs (ALB ~\$16/mo + NAT gateway +
Fargate). When you're done learning, destroy everything:

```bash
terraform destroy   # type 'yes' to confirm
```

`terraform destroy` removes every resource this config created, which is
the big advantage over console clicking: nothing is left behind to
surprise you on the bill.

## Going further

- Store state remotely (uncomment the S3 backend in `versions.tf`).
- Add an HTTPS listener with an ACM certificate + Route 53 domain.
- Add application auto-scaling based on CPU/requests.
- Switch the pipeline to GitHub OIDC so no AWS keys are stored at all.
