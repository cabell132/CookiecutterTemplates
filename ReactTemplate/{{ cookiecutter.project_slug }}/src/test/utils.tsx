import { render, type RenderOptions } from "@testing-library/react";
import type { ReactElement } from "react";

import { Providers } from "@/app/providers";

/**
 * Custom render that wraps components with application providers.
 * @param ui - The React element to render.
 * @param options - Additional render options.
 * @returns The render result.
 */
function customRender(ui: ReactElement, options?: Omit<RenderOptions, "wrapper">) {
  return render(ui, { wrapper: Providers, ...options });
}

export { customRender as render };
export { screen, within, waitFor } from "@testing-library/react";
export { default as userEvent } from "@testing-library/user-event";
