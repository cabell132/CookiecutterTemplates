import { useExample } from "@/features/example/hooks/useExample";

/**
 * Example feature component demonstrating the feature-based pattern.
 * @returns The rendered example feature.
 */
export function ExampleFeature(): React.JSX.Element {
  const { items, addItem } = useExample();

  return (
    <div className="mx-auto max-w-md space-y-4">
      <h1 className="text-2xl font-bold">{{ cookiecutter.project_name }}</h1>
      <p className="text-gray-600">{{ cookiecutter.description }}</p>

      <button
        type="button"
        onClick={() => addItem(`Item ${items.length + 1}`)}
        className="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700"
      >
        Add Item
      </button>

      <ul className="space-y-2">
        {items.map((item) => (
          <li key={item.id} className="rounded border p-2">
            {item.name}
          </li>
        ))}
      </ul>
    </div>
  );
}
