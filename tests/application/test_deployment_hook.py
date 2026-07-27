import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT
    / "terraform"
    / "patterns"
    / "native-deployment"
    / "hooks"
    / "deployment_hook.py"
)


class DeploymentHookTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location(
            "deployment_hook",
            MODULE_PATH,
        )
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def test_returns_the_ecs_lifecycle_hook_response(self):
        event = {
            "resourceArn": (
                "arn:aws:ecs:us-west-2:123456789012:"
                "service-deployment/cluster/service/deployment"
            ),
            "executionId": "hook-execution-id",
        }

        result = self.module.handler(event, None)

        self.assertEqual(result, {"hookStatus": "SUCCEEDED"})
        self.assertNotIn("status", result)


if __name__ == "__main__":
    unittest.main()
