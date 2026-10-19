"""
test_app.py - the quality gate.

These tests run automatically in the pipeline. If any test fails,
the pipeline stops and the broken code never gets deployed.
That is the core safety mechanism of CI (Continuous Integration).
"""
import pytest

from app.main import create_app, add_numbers


@pytest.fixture
def client():
    """A test client lets us call our endpoints without a real server.

    pytest fixtures provide reusable setup. Here we build the app
    once and hand each test a fresh client to make requests with.
    """
    app = create_app()
    app.config.update(TESTING=True)
    with app.test_client() as client:
        yield client


def test_home(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "DevOps Lab" in resp.get_json()["message"]


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_add_endpoint(client):
    resp = client.get("/add/2/3")
    assert resp.status_code == 200
    assert resp.get_json()["result"] == 5


def test_add_numbers_unit():
    # A plain unit test of the pure function, no HTTP involved.
    assert add_numbers(10, 15) == 25
    assert add_numbers(-1, 1) == 0
