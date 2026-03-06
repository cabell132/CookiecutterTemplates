/** Application configuration derived from environment variables. */
export const config = {
  appTitle: import.meta.env.VITE_APP_TITLE ?? "{{ cookiecutter.project_name }}",
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api",
} as const;
