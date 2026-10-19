# DevOps Lab: A CI/CD Pipeline From Start to Finish

A hands-on, beginner-friendly lab that takes a tiny web app all the way
through a real pipeline: **build → test → package → deploy**. Every file
is commented so you can read the code and the concepts together.

---

## The big picture

A **CI/CD pipeline** is an automated assembly line for your code. Every
time you change the code, the pipeline runs these stages automatically:

```
  You push code
        |
        v
  +--------------+     +----------------+     +------------------+     +-------------+
  |  BUILD/TEST  | --> |  PACKAGE       | --> |  SMOKE TEST      | --> |  DEPLOY     |
  |  (pytest)    |     |  (Docker image)|     |  (run container) |     | (to server) |
  +--------------+     +----------------+     +------------------+     +-------------+
     quality gate         portable artifact     prove it runs          ship it

  If ANY stage fails, the pipeline stops and later stages never run.
```

- **CI (Continuous Integration):** automatically build and test every change.
- **CD (Continuous Deployment):** automatically ship changes that pass.

---

## What's in this repo

| File | Role in the pipeline |
|------|----------------------|
| `app/main.py` | The web app we are shipping (Flask). |
| `tests/test_app.py` | The **quality gate**: tests that must pass. |
| `requirements.txt` | Pinned dependencies, so builds are reproducible. |
| `Dockerfile` | Recipe to **package** the app into a container image. |
| `.dockerignore` | Keeps junk out of the image. |
| `docker-compose.yml` | Run the app locally like a mini production setup. |
| `.github/workflows/pipeline.yml` | The **pipeline** itself (GitHub Actions). |
| `ARCHITECTURE.md` | Diagrams + explanations of the whole system and AWS. |
| `aws/task-definition.json` | ECS Fargate blueprint for running the container. |
| `AWS_SETUP.md` | Step-by-step to deploy to AWS (ECR + ECS Fargate). |

---

## The app

Three endpoints so there's something real to test and deploy:

| Endpoint | What it returns |
|----------|-----------------|
| `GET /` | A greeting message. |
| `GET /health` | `{"status": "ok"}` — used to check the app is alive. |
| `GET /add/2/3` | `{"result": 5}` — a bit of logic to unit test. |

---

## Run it yourself

### Prerequisites
- Python 3.12+  (check: `python --version`)
- Docker Desktop, for the container parts  (check: `docker --version`)

### Option A — run the app directly with Python

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m app.main
```

Open http://localhost:5000 in your browser.

### Option B — run the tests (the quality gate)

```powershell
pip install -r requirements.txt
pytest -v
```

Green = safe to ship. Red = the pipeline would stop here.

### Option C — run it in a container with Docker Compose

```powershell
docker compose up --build
```

Open http://localhost:5000. Stop with `Ctrl+C`, then `docker compose down`.

---

## How the pipeline runs automatically

The moment you push this project to a GitHub repository, GitHub reads
`.github/workflows/pipeline.yml` and runs it. It has three jobs that run
in order, each one gated on the previous:

1. **build-and-test** — installs dependencies and runs `pytest`.
   If a test fails, everything stops here.
2. **docker-build** — builds the Docker image and runs a smoke test
   (starts the container and checks `/health`).
3. **deploy** — ships the app. If you've configured AWS (see
   `AWS_SETUP.md`), the `deploy-aws` job pushes to **ECR** and rolls out
   on **ECS Fargate**. If not, a simulated deploy runs instead. Only on
   the `main` branch.

> Want the cloud version? Read `ARCHITECTURE.md` for the diagrams, then
> follow `AWS_SETUP.md` to deploy to AWS for real.

Watch it live under the **Actions** tab of your GitHub repo.

### Push it to GitHub

```powershell
git init
git add .
git commit -m "DevOps lab: app, tests, Docker, and CI/CD pipeline"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```

Then open the **Actions** tab and watch each stage light up.

---

## Suggested experiments (this is how you learn)

1. **Break a test on purpose.** Change `add_numbers` to `a - b`, push,
   and watch the pipeline go red and block the deploy.
2. **Add a new endpoint** (e.g. `/multiply/<a>/<b>`), write a test for it,
   and watch the pipeline validate your change.
3. **Add a real deploy.** Swap the simulated `deploy` job for one that
   pushes the image to a registry and deploys to a free host.

---

## Glossary

- **Artifact:** the packaged output of a build (here, a Docker image).
- **Runner:** the fresh virtual machine that executes pipeline steps.
- **Trigger:** the event that starts the pipeline (a push, a PR).
- **Quality gate:** a check (like tests) that must pass to continue.
- **Smoke test:** a quick check that the thing at least starts and runs.
