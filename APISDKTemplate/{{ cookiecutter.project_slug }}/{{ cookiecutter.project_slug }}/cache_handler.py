"""Pluggable token cache handlers for {{ cookiecutter.service_name }} SDK."""

from __future__ import annotations

import json
import os
from abc import ABC, abstractmethod


class CacheHandler(ABC):
    """Abstract base for token cache backends."""

    @abstractmethod
    def get_cached_token(self) -> dict | None:  # type: ignore[type-arg]
        """Retrieve a cached token, or None if not available."""
        ...

    @abstractmethod
    def save_token_to_cache(self, token_info: dict) -> None:  # type: ignore[type-arg]
        """Persist a token to the cache."""
        ...


class CacheFileHandler(CacheHandler):
    """Saves token to a JSON file on disk."""

    def __init__(self, cache_path: str = ".cache-token") -> None:
        self.cache_path = cache_path

    def get_cached_token(self) -> dict | None:  # type: ignore[type-arg]
        if not os.path.exists(self.cache_path):
            return None
        with open(self.cache_path) as f:
            return json.load(f)  # type: ignore[no-any-return]

    def save_token_to_cache(self, token_info: dict) -> None:  # type: ignore[type-arg]
        with open(self.cache_path, "w") as f:
            json.dump(token_info, f)
        os.chmod(self.cache_path, 0o600)


class MemoryCacheHandler(CacheHandler):
    """In-memory cache — tokens lost when process ends."""

    def __init__(self) -> None:
        self._token: dict | None = None  # type: ignore[type-arg]

    def get_cached_token(self) -> dict | None:  # type: ignore[type-arg]
        return self._token

    def save_token_to_cache(self, token_info: dict) -> None:  # type: ignore[type-arg]
        self._token = token_info
