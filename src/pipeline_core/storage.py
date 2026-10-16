from __future__ import annotations

from typing import Protocol


class Store(Protocol):
    def list_keys(self, prefix: str) -> list[str]: ...
    def get(self, key: str) -> bytes: ...
    def put(self, key: str, data: bytes) -> None: ...
    def copy(self, source: str, target: str) -> None: ...
    def delete(self, key: str) -> None: ...
    def exists(self, key: str) -> bool: ...


class MemoryStore:
    def __init__(self, objects: dict[str, bytes] | None = None) -> None:
        self.objects: dict[str, bytes] = dict(objects or {})

    def list_keys(self, prefix: str) -> list[str]:
        return sorted(k for k in self.objects if k.startswith(prefix))

    def get(self, key: str) -> bytes:
        return self.objects[key]

    def put(self, key: str, data: bytes) -> None:
        self.objects[key] = bytes(data)

    def copy(self, source: str, target: str) -> None:
        self.objects[target] = self.objects[source]

    def delete(self, key: str) -> None:
        self.objects.pop(key, None)

    def exists(self, key: str) -> bool:
        return key in self.objects