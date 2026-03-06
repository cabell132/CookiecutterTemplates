import { createBrowserRouter } from "react-router";
import { ExampleFeature } from "@/features/example";

/** Application route definitions. */
export const router = createBrowserRouter([
  {
    path: "/",
    element: (
      <main className="min-h-screen bg-gray-50 p-8">
        <ExampleFeature />
      </main>
    ),
  },
]);
