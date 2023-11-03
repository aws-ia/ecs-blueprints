import pytest
import flask
#pylint: disable=E0401
from app import create_app

app_mock = flask.Flask(__name__)

#pylint: disable=W0621
@pytest.fixture()
def app():
    app = create_app()
    yield app

#pylint: disable=W0621
@pytest.fixture()
def client(app):
    return app.test_client()

#pylint: disable=W0621
@pytest.fixture()
def runner(app):
    return app.test_cli_runner()

#pylint: disable=W0621
def test_flask_server(client):
    expected_response = b'<!DOCTYPE html>\n<html lang="en">\n<head>\n    <meta charset="UTF-8">\n    <meta name="viewport" content="width=device-width, initial-scale=1" />\n    <title>Amazon ECS Simple App</title>\n    <link rel="stylesheet" href="static/css/style.css" />\n</head>\n<body>\n    <header class="bg-primary text-white text-center py-5">\n        <p style="text-align:center;">\n            <img src="/static/amazon-ecs.png" alt="Amazon ECS Logo" width="100">\n        </p>\n        <h1>Amazon ECS Flask Webpage</h1>\n    </header>\n    <main class="container">\n        <h2>Congratulations!</h2>\n        <p>Your Flask application is now running on a container in <b>AWS-version 0.0.0</b></p>\n        <p>This container is running Flask-version 2.3.2</p>\n    </main>\n</body>\n</html>'
    response = client.get("/")
    assert expected_response == response.data
