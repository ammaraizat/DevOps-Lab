# Dockerfile - the recipe for packaging our app into a container image.
#
# Each line is an instruction. Docker runs them top to bottom and
# caches each step, so unchanged steps are reused on the next build.

# 1. Start FROM a base image: a minimal Linux that already has Python.
#    "slim" is a smaller variant, which keeps our image lightweight.
FROM python:3.12-slim

# 2. Set the working directory inside the container. Every command
#    after this runs from /app.
WORKDIR /app

# 3. Copy ONLY requirements first, then install. Because Docker caches
#    layers, dependencies are re-installed only when requirements.txt
#    changes, not every time we edit our code. This speeds up builds.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Now copy the rest of the application source code.
COPY app/ ./app/

# 5. Document that the app listens on port 5000 inside the container.
EXPOSE 5000

# 6. The command that runs when the container starts.
#    We use gunicorn, a production-grade server, instead of Flask's
#    built-in development server. It serves the `app` object returned
#    by create_app() in app/main.py.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app.main:create_app()"]
