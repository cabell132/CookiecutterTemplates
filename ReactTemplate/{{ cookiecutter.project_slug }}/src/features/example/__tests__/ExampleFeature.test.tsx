import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { ExampleFeature } from "@/features/example/components/ExampleFeature";

describe("ExampleFeature", () => {
  it("renders the heading", () => {
    render(<ExampleFeature />);
    expect(screen.getByRole("heading", { level: 1 })).toBeInTheDocument();
  });

  it("adds an item when button is clicked", async () => {
    const user = userEvent.setup();
    render(<ExampleFeature />);

    await user.click(screen.getByRole("button", { name: /add item/i }));

    expect(screen.getByText("Item 1")).toBeInTheDocument();
  });

  it("adds multiple items", async () => {
    const user = userEvent.setup();
    render(<ExampleFeature />);

    await user.click(screen.getByRole("button", { name: /add item/i }));
    await user.click(screen.getByRole("button", { name: /add item/i }));

    expect(screen.getByText("Item 1")).toBeInTheDocument();
    expect(screen.getByText("Item 2")).toBeInTheDocument();
  });
});
