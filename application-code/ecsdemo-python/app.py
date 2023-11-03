import datetime
import platform
import os
import sys
import logging
import flask

LOG_LEVEL = logging.INFO
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)
log_handler = logging.StreamHandler(sys.stdout)
logger.addHandler(log_handler)

def create_app():
    #pylint: disable=W0621
    app = flask.Flask(__name__)
    @app.route('/')
    def hello():
        logger.info('--------GET Root---------')

        app_name = os.environ.get('APP_NAME', 'Amazon ECS Flask Webpage')
        container_service = os.environ.get('CONTAINER_SERVICE', 'AWS')
        infra_version = os.environ.get('INFRA_VERSION', '0.0.0')
        python_version = platform.python_version()
        now = datetime.datetime.now()

        return flask.render_template(
            'index.html',
            name=app_name,
            platform=container_service,
            infra_version=infra_version,
            flask_version=flask.__version__,
            python_version=python_version,
            time=now
        )
    return app

if __name__ == '__main__':
    app = create_app()
    HOST = '0.0.0.0' #nosec
    port = int(os.environ.get('PORT_IN', '3000'))
    logger.info('--------start main---------')
    app.run(host=HOST, port=port)
