"""Pydantic models for {{ cookiecutter.service_name }} API responses and requests."""

from __future__ import annotations

from datetime import datetime

from pydantic import AnyUrl, BaseModel

# ---------------------------------------------------------------------------
# Nested / summary models (no response_url)
# ---------------------------------------------------------------------------


class ItemNested(BaseModel):
    """Minimal item representation when embedded in another model."""

    id: int
    name: str
    slug: str


# ---------------------------------------------------------------------------
# List models
# ---------------------------------------------------------------------------


class ItemList(BaseModel):
    """Item representation in list/search results."""

    id: int
    name: str
    slug: str
    status: str
    created_at: datetime | None = None


# ---------------------------------------------------------------------------
# Detail models (full response with response_url)
# ---------------------------------------------------------------------------


class ItemDetail(BaseModel):
    """Full API response for a single item."""

    id: int
    name: str
    slug: str
    description: str | None = None
    status: str
    created_at: datetime | None = None
    response_url: AnyUrl


# ---------------------------------------------------------------------------
# Paginated wrapper models
# ---------------------------------------------------------------------------


class PaginatedItemList(BaseModel):
    """Paginated list of items."""

    count: int
    next: str | None = None
    previous: str | None = None
    page: int | None = None
    per_page: int | None = None
    results: list[ItemList]
    response_url: AnyUrl


# ---------------------------------------------------------------------------
# Request body models
# ---------------------------------------------------------------------------


class CreateItemRequest(BaseModel):
    """Request body for creating a new item."""

    name: str
    description: str | None = None
    status: str = "active"
