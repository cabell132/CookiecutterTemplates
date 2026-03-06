/** Common application types. */

/** Generic API response wrapper. */
export interface ApiResponse<T> {
  data: T;
  message?: string;
}

/** Discriminated union for async state. */
export type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };
