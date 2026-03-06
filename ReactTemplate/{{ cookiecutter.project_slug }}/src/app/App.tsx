{%- if cookiecutter.include_router == "yes" %}
import { RouterProvider } from "react-router";
import { router } from "@/app/router";
{%- endif %}
import { Providers } from "@/app/providers";
{%- if cookiecutter.include_router != "yes" %}
import { ExampleFeature } from "@/features/example";
{%- endif %}

/**
 * Root application component.
 * @returns The rendered application.
 */
export function App(): React.JSX.Element {
  return (
    <Providers>
{%- if cookiecutter.include_router == "yes" %}
      <RouterProvider router={router} />
{%- else %}
      <main className="min-h-screen bg-gray-50 p-8">
        <ExampleFeature />
      </main>
{%- endif %}
    </Providers>
  );
}
