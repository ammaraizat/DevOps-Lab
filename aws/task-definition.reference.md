# ECS Task Definition — field-by-field reference

The actual file (`task-definition.json`) is kept clean so AWS accepts it.
This document explains what every field means. A **task definition** is the
blueprint ECS uses to run one copy (a "task") of your container.

| Field | Meaning |
|-------|---------|
| `family` | The name/grouping for this task definition. New versions are "revisions" of the same family. |
| `networkMode: awsvpc` | Each task gets its own network interface and private IP. Required for Fargate. |
| `requiresCompatibilities: [FARGATE]` | Run serverless (no EC2 servers to manage). |
| `cpu: "256"` | 256 units = 0.25 vCPU. Smallest/cheapest size. |
| `memory: "512"` | 512 MB RAM. Must pair with the allowed CPU values. |
| `executionRoleArn` | IAM role ECS itself uses to pull the image from ECR and write logs to CloudWatch. |
| `taskRoleArn` | IAM role YOUR app code uses (e.g. to read S3). Our app needs nothing, kept for learning. |
| `containerDefinitions` | The list of containers in the task. We have one: `web`. |
| `image` | Which image to run. **The pipeline overwrites this** with the exact tag it just pushed to ECR. |
| `essential: true` | If this container dies, the whole task is stopped (and ECS replaces it). |
| `portMappings.containerPort: 5000` | The port gunicorn listens on inside the container; the ALB forwards here. |
| `healthCheck` | Container-level check that runs inside the container and hits `/health`. |
| `logConfiguration (awslogs)` | Ships stdout/stderr to the CloudWatch log group `/ecs/devops-lab`. |

## Placeholders to replace during setup

| Placeholder | Example | Where to find it |
|-------------|---------|------------------|
| `<ACCOUNT_ID>` | `123456789012` | AWS Console top-right, or `aws sts get-caller-identity` |
| `<REGION>` | `us-east-1` | The region you deploy into |

## CPU / memory combos (Fargate)

Fargate only allows specific pairings. The smallest:

| CPU | Valid memory values |
|-----|---------------------|
| 256 (.25 vCPU) | 512, 1024, 2048 |
| 512 (.5 vCPU) | 1024 – 4096 |
| 1024 (1 vCPU) | 2048 – 8192 |
