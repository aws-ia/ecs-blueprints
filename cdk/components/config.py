TRUE_VALUES = {"1", "true", "yes", "on"}
FALSE_VALUES = {"0", "false", "no", "off"}


def parse_bool(value):
    if isinstance(value, bool):
        return value

    normalized = str(value).strip().lower()
    if normalized in TRUE_VALUES:
        return True
    if normalized in FALSE_VALUES:
        return False
    raise ValueError(f"Expected a boolean value, received {value!r}")


def find_namespace(namespaces, namespace_name):
    """Return the first service discovery namespace matching namespace_name.

    Raises ValueError with an actionable message when nothing matches instead
    of the bare IndexError a ``[...][0]`` lookup would produce.
    """
    for namespace in namespaces:
        if namespace.namespace_name == namespace_name:
            return namespace
    raise ValueError(
        f"No service discovery namespace named {namespace_name!r} was found in "
        "the core infrastructure stack. Deploy the core_infra stack with this "
        "namespace (check the 'namespaces' and 'namespace_name' values in your "
        ".env) before deploying this service."
    )
