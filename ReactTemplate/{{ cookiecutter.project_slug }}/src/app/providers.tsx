{%- if cookiecutter.include_tanstack_query == "yes" %}
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
{%- endif %}
import { ErrorBoundary } from "@/components/ErrorBoundary";

{%- if cookiecutter.include_tanstack_query == "yes" %}

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,
      retry: 1,
    },
  },
});
{%- endif %}

/**
 * Application-wide providers wrapper.
 * @param props - Component props.
 * @param props.children - Child elements to wrap.
 * @returns The wrapped children with all providers.
 */
export function Providers({ children }: { children: React.ReactNode }): React.JSX.Element {
  return (
    <ErrorBoundary>
{%- if cookiecutter.include_tanstack_query == "yes" %}
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
{%- else %}
      {children}
{%- endif %}
    </ErrorBoundary>
  );
}
