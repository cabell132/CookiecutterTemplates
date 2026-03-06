import { RuntimeError } from "@/lib/errors";

/**
 * Lightweight fetch wrapper with error handling.
 * @param url - The URL to fetch.
 * @param options - Fetch options.
 * @returns The parsed JSON response.
 */
export async function apiClient<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    headers: { "Content-Type": "application/json", ...options?.headers },
    ...options,
  });

  if (!response.ok) {
    throw new RuntimeError(`API error: ${response.status} ${response.statusText}`);
  }

  return response.json() as Promise<T>;
}
