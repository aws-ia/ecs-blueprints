import importlib.util
import json
import os
import pathlib
import sys
import types
import unittest
import uuid


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT / "application-code" / "message-producer" / "lambda_function.py"
)


class FakeQueue:
    def __init__(self):
        self.sent = []

    def send_message(self, **kwargs):
        self.sent.append(kwargs)
        return {}


class FakeSqs:
    def __init__(self):
        self.queue = FakeQueue()

    def get_queue_by_name(self, QueueName):
        return self.queue


class FakeSession:
    fake_sqs = None

    def resource(self, service, **kwargs):
        FakeSession.fake_sqs = FakeSqs()
        return FakeSession.fake_sqs


class MessageProducerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.previous_modules = {
            name: sys.modules.get(name)
            for name in ("boto3", "botocore", "botocore.config")
        }
        sys.modules["boto3"] = types.SimpleNamespace(
            Session=lambda: FakeSession(),
        )
        sys.modules["botocore"] = types.ModuleType("botocore")
        sys.modules["botocore.config"] = types.SimpleNamespace(
            Config=lambda **kwargs: types.SimpleNamespace(**kwargs)
        )
        os.environ["queue_name"] = "processing-queue.fifo"
        os.environ["default_msg_proc_duration"] = "5"
        os.environ["number_of_messages"] = "50"

        spec = importlib.util.spec_from_file_location(
            "message_producer", MODULE_PATH
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

    def run_handler(self):
        # The sqs resource (and the fake queue) is created once at module
        # import, so slice off only the messages sent by this invocation.
        already_sent = len(FakeSession.fake_sqs.queue.sent)
        self.module.lambda_handler({}, None)
        return FakeSession.fake_sqs.queue.sent[already_sent:]

    def test_sends_configured_number_of_messages(self):
        sent = self.run_handler()
        self.assertEqual(len(sent), 50)

    def test_dedup_ids_are_unique(self):
        sent = self.run_handler()
        dedup_ids = [msg["MessageDeduplicationId"] for msg in sent]
        self.assertEqual(len(dedup_ids), len(set(dedup_ids)))

    def test_dedup_ids_are_uuids(self):
        sent = self.run_handler()
        for msg in sent:
            # Raises ValueError (failing the test) if not a valid UUID
            parsed = uuid.UUID(msg["MessageDeduplicationId"])
            self.assertEqual(str(parsed), msg["MessageDeduplicationId"])

    def test_group_id_matches_message_id(self):
        sent = self.run_handler()
        for msg in sent:
            body = json.loads(msg["MessageBody"])
            self.assertEqual(msg["MessageGroupId"], body["id"])
            self.assertEqual(msg["MessageDeduplicationId"], body["id"])

    def test_body_contains_configured_duration(self):
        sent = self.run_handler()
        for msg in sent:
            body = json.loads(msg["MessageBody"])
            self.assertEqual(body["duration"], 5)

    def test_dedup_ids_unique_across_invocations(self):
        first = {msg["MessageDeduplicationId"] for msg in self.run_handler()}
        second = {msg["MessageDeduplicationId"] for msg in self.run_handler()}
        self.assertFalse(first & second)


if __name__ == "__main__":
    unittest.main()
