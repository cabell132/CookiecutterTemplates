/** Base application error — all custom errors extend this. */
export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly cause?: unknown,
  ) {
    super(message);
    this.name = "AppError";
  }
}

/** Validation errors (user input, form data, API responses). */
export class ValidationError extends AppError {
  constructor(message: string, cause?: unknown) {
    super(message, "VALIDATION_ERROR", cause);
    this.name = "ValidationError";
  }
}

/** Runtime errors (network failures, unexpected state). */
export class RuntimeError extends AppError {
  constructor(message: string, cause?: unknown) {
    super(message, "RUNTIME_ERROR", cause);
    this.name = "RuntimeError";
  }
}
