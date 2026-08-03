import importlib.util
import os
import pathlib
import sys
import types
import unittest
from unittest import mock


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "application-code" / "data-pipeline-task" / "task.py"


class DataPipelineTaskTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.previous_boto3 = sys.modules.get("boto3")
        sys.modules["boto3"] = types.SimpleNamespace(
            client=lambda service: mock.Mock()
        )
        spec = importlib.util.spec_from_file_location(
            "data_pipeline_task", MODULE_PATH
        )
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    @classmethod
    def tearDownClass(cls):
        if cls.previous_boto3 is None:
            sys.modules.pop("boto3", None)
        else:
            sys.modules["boto3"] = cls.previous_boto3

    def setUp(self):
        self.module.workflow_client.reset_mock()

    def test_malformed_files_reports_failure_and_exits_nonzero(self):
        environment = {
            "S3_BUCKET": "source",
            "FOLDERNAME": "incoming",
            "TASK_TOKEN": "callback-token",
            "FILES": "not-json",
        }

        with mock.patch.dict(os.environ, environment, clear=True):
            with self.assertRaises(ValueError):
                self.module.main()

        self.module.workflow_client.send_task_failure.assert_called_once()
        call = self.module.workflow_client.send_task_failure.call_args.kwargs
        self.assertEqual(call["taskToken"], "callback-token")
        self.assertEqual(call["error"], "DataProcessingException")

    def test_missing_context_does_not_raise_unbound_local_error(self):
        with mock.patch.dict(
            os.environ,
            {"TASK_TOKEN": "callback-token"},
            clear=True,
        ):
            with self.assertRaises(KeyError):
                self.module.main()

        self.module.workflow_client.send_task_failure.assert_called_once()


if __name__ == "__main__":
    unittest.main()
