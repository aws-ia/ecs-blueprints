import json
import logging


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def handler(event, _context):
    LOGGER.info("Validating deployment hook event: %s", json.dumps(event))
    return {"hookStatus": "SUCCEEDED"}
