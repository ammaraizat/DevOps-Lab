"""
main.py - our tiny web application.

This is the "product" that our DevOps pipeline will build, test,
package, and deploy. Keeping it small lets us focus on the pipeline,
not the app itself.
"""
from flask import Flask, jsonify


def create_app():
    """Create and configure the Flask application.

    Using a factory function (create_app) instead of a global `app`
    makes the application easy to import in tests without starting
    a real server. This is a common, testable Flask pattern.
    """
    app = Flask(__name__)

    @app.route("/")
    def home():
        # A friendly landing endpoint.
        return jsonify(
            message="Hello from the DevOps Lab!",
            hint="Try the /health and /add endpoints too.",
        )

    @app.route("/health")
    def health():
        # Health checks let a pipeline or orchestrator know the app
        # is alive. Deployment tools poll endpoints like this.
        return jsonify(status="ok"), 200

    @app.route("/add/<int:a>/<int:b>")
    def add(a, b):
        # A trivial bit of "business logic" so we have something
        # meaningful to write a unit test against.
        return jsonify(a=a, b=b, result=add_numbers(a, b))

    return app


def add_numbers(a, b):
    """Pure function holding our 'business logic'.

    Pure functions (no side effects) are the easiest things to test,
    which is exactly what makes them good examples for a testing stage.
    """
    return a + b


# When run directly (python -m app.main), start a development server.
if __name__ == "__main__":
    application = create_app()
    application.run(host="0.0.0.0", port=5000)
