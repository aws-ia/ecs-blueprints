def strtobool(value):
    normalized = value.lower()
    if normalized in ("y", "yes", "t", "true", "on", "1"):
        return 1
    if normalized in ("n", "no", "f", "false", "off", "0"):
        return 0
    raise ValueError(f"invalid truth value {value!r}")
