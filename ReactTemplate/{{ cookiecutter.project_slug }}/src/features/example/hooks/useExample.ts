import { useState } from "react";
import type { ExampleItem } from "@/features/example/schemas/example.schema";

/**
 * Custom hook demonstrating the hook pattern for feature state.
 * @returns Object with items array and addItem function.
 */
export function useExample(): {
  items: ExampleItem[];
  addItem: (name: string) => void;
} {
  const [items, setItems] = useState<ExampleItem[]>([]);

  const addItem = (name: string): void => {
    setItems((prev) => [...prev, { id: crypto.randomUUID(), name }]);
  };

  return { items, addItem } as const;
}
