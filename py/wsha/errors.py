"""Custom exceptions for wsha."""


class WshaError(Exception):
    """Base exception for wsha."""
    pass


class ConfigParseError(WshaError):
    """Raised when a config file has parse errors."""

    def __init__(self, message: str, config_path: str, line_no: int):
        self.message = message
        self.config_path = config_path
        self.line_no = line_no
        super().__init__(f"{config_path}:{line_no}: {message}")


class DuplicateAliasError(ConfigParseError):
    """Raised when a duplicate alias is found in a config file."""

    def __init__(self, alias: str, config_path: str, line_no: int):
        self.alias = alias
        super().__init__(
            f'duplicate alias "{alias}"',
            config_path,
            line_no
        )


class CacheError(WshaError):
    """Raised when there's a cache-related error."""
    pass


class ConfigNotFoundError(WshaError):
    """Raised when no config files are found."""
    pass
