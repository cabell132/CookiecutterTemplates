import { z } from "zod/v4";

/** Schema for an example item. */
export const ExampleItemSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1, "Name is required"),
});

/** TypeScript type derived from the Zod schema. */
export type ExampleItem = z.infer<typeof ExampleItemSchema>;
