import importlib.util
import os
import pathlib
import sys
import types
import unittest
from unittest import mock


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT / "application-code" / "container-queue-proc" / "src" / "app.py"
)


class FakeMessage:
    def __init__(self, body):
        self.body = body
        self.message_id = "message-1"


class QueueProcessorTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.previous_modules = {
            name: sys.modules.get(name)
            for name in ("boto3", "botocore", "botocore.exceptions", "PIL")
        }
        sys.modules["boto3"] = types.SimpleNamespace(
            resource=lambda service: object(),
            client=lambda service: object(),
        )
        client_error = type("ClientError", (Exception,), {})
        sys.modules["botocore"] = types.ModuleType("botocore")
        sys.modules["botocore.exceptions"] = types.SimpleNamespace(
            ClientError=client_error
        )
        sys.modules["PIL"] = types.SimpleNamespace(Image=object())
        os.environ["PIPELINE_S3_DEST_PREFIX"] = "processed"

        spec = importlib.util.spec_from_file_location(
            "queue_processor", MODULE_PATH
        )
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    @classmethod
    def tearDownClass(cls):
        for name, previous in cls.previous_modules.items():
            if previous is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = previous

    def test_s3_test_event_is_successful_noop(self):
        self.assertIsNone(
            self.module.process_message(FakeMessage('{"Event":"s3:TestEvent"}'))
        )

    def test_malformed_event_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.process_message(FakeMessage('{"Records":[]}'))

    def test_all_s3_records_are_processed_before_message_succeeds(self):
        message = FakeMessage(
            """
            {
              "Records": [
                {
                  "s3": {
                    "bucket": {"name": "source"},
                    "object": {"key": "first.jpg"}
                  }
                },
                {
                  "s3": {
                    "bucket": {"name": "source"},
                    "object": {"key": "second.jpg"}
                  }
                }
              ]
            }
            """
        )
        fake_s3 = mock.Mock()

        with mock.patch.object(self.module, "s3_client", fake_s3), \
                mock.patch.object(self.module, "resize_image"):
            self.module.process_message(message)

        self.assertEqual(fake_s3.download_file.call_count, 2)
        self.assertEqual(fake_s3.upload_file.call_count, 2)
        fake_s3.download_file.assert_has_calls(
            [
                mock.call("source", "first.jpg", "/tmp/ecsproc/first.jpg"),
                mock.call("source", "second.jpg", "/tmp/ecsproc/second.jpg"),
            ]
        )


if __name__ == "__main__":
    unittest.main()
