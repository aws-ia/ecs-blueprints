from aws_cdk import App
from lib.express_mode_stack import ExpressModeStack


app = App()
enable_custom = str(
    app.node.try_get_context("enableCustomTaskDefinition")
).lower() in {"1", "true", "yes"}
ExpressModeStack(
    app,
    "ExpressMode",
    enable_custom_task_definition=enable_custom,
)
app.synth()
