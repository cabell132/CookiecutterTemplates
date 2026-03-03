"""Items resource for {{ cookiecutter.service_name }} API."""

from __future__ import annotations

from {{ cookiecutter.project_slug }}.base import Base
from {{ cookiecutter.project_slug }}.models import (
    CreateItemRequest,
    ItemDetail,
    PaginatedItemList,
)
from {{ cookiecutter.project_slug }}.session import {{ cookiecutter.service_name }}Session


class Items(Base):
    """Resource class for the /items endpoint."""

    def __init__(self, session: {{ cookiecutter.service_name }}Session) -> None:
        super().__init__(session)
        self.endpoint = "items"

    def search(
        self,
        name: str | None = None,
        status: str | None = None,
        page: int | None = None,
        per_page: int | None = None,
    ) -> PaginatedItemList:
        """Search items with optional filters and pagination."""
        params = {"name": name, "status": status, "page": page, "per_page": per_page}
        data = self.session.make_request(
            method="GET", endpoint=f"{self.endpoint}/", params=params
        )
        self.fix_pagination_urls(data)
        return PaginatedItemList(**data)

    def get(self, id: str | int) -> ItemDetail:
        """Get a single item by ID."""
        data = self.session.make_request(
            method="GET", endpoint=f"{self.endpoint}/{id}/"
        )
        return ItemDetail(**data)

    def create(self, item: CreateItemRequest) -> ItemDetail:
        """Create a new item."""
        data = self.session.make_request(
            method="POST",
            endpoint=f"{self.endpoint}/",
            json=item.model_dump(),
        )
        return ItemDetail(**data)
