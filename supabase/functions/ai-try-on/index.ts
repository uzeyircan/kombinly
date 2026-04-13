import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GEMINI_MODEL = "gemini-2.5-flash-image";
const RESULT_BUCKET = "ai-try-on-results";
const RESULT_FOLDER = "generated";

type GenerationRequest = {
  generationId: string;
  mannequinImageUrl: string;
  garmentImageUrl: string;
  prompt: string;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function ensureEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

function inferMimeType(url: string, responseContentType: string | null): string {
  if (responseContentType && responseContentType.startsWith("image/")) {
    return responseContentType;
  }

  const normalized = url.toLowerCase();
  if (normalized.endsWith(".png")) return "image/png";
  if (normalized.endsWith(".webp")) return "image/webp";
  if (normalized.endsWith(".jpeg") || normalized.endsWith(".jpg")) {
    return "image/jpeg";
  }

  return "image/png";
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;

  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }

  return btoa(binary);
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);

  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes;
}

async function fetchImageAsInlineData(url: string) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch image: ${url} (${response.status})`);
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  return {
    mimeType: inferMimeType(url, response.headers.get("content-type")),
    data: bytesToBase64(bytes),
  };
}

async function updateGeneration(
  supabase: ReturnType<typeof createSupabaseClient>,
  generationId: string,
  values: Record<string, unknown>,
) {
  const { error } = await supabase
    .from("ai_try_on_generations")
    .update(values)
    .eq("id", generationId);

  if (error) {
    throw new Error(`Failed to update generation ${generationId}: ${error.message}`);
  }
}

function createSupabaseClient() {
  const supabaseUrl = ensureEnv("SUPABASE_URL");
  const serviceRoleKey = ensureEnv("SUPABASE_SERVICE_ROLE_KEY");

  return createClient(
    supabaseUrl,
    serviceRoleKey,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    },
  );
}

async function callGeminiEditAPI(input: GenerationRequest) {
  const geminiApiKey = ensureEnv("GEMINI_API_KEY");

  const mannequinImage = await fetchImageAsInlineData(input.mannequinImageUrl);
  const garmentImage = await fetchImageAsInlineData(input.garmentImageUrl);

  // Inference from official docs and forum reports:
  // image editing is most reliable when reference images are sent as inlineData.
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${geminiApiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              { text: input.prompt },
              {
                inlineData: {
                  mimeType: mannequinImage.mimeType,
                  data: mannequinImage.data,
                },
              },
              {
                inlineData: {
                  mimeType: garmentImage.mimeType,
                  data: garmentImage.data,
                },
              },
            ],
          },
        ],
      }),
    },
  );

  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(parseGeminiErrorMessage(response.status, responseText));
  }

  const payload = JSON.parse(responseText);
  const parts: Array<Record<string, unknown>> =
    payload?.candidates?.[0]?.content?.parts ?? [];

  const imagePart = parts.find((part) => part.inlineData);
  if (!imagePart || !imagePart.inlineData) {
    throw new Error("Gemini response did not contain an image part");
  }

  const inlineData = imagePart.inlineData as { mimeType?: string; data?: string };
  if (!inlineData.data) {
    throw new Error("Gemini response image data was empty");
  }

  return {
    mimeType: inlineData.mimeType ?? "image/png",
    bytes: base64ToBytes(inlineData.data),
  };
}

function parseGeminiErrorMessage(status: number, responseText: string): string {
  let message = responseText;

  try {
    const payload = JSON.parse(responseText);
    if (typeof payload?.error?.message === "string") {
      message = payload.error.message;
    }
  } catch (_) {
    // Keep the raw response text when Gemini returns a non-JSON error body.
  }

  const normalized = message.toLowerCase();
  if (
    status === 429 ||
    normalized.includes("resource_exhausted") ||
    normalized.includes("quota exceeded") ||
    normalized.includes("generate_content_free_tier")
  ) {
    return "Gemini image generation quota is exhausted. Try again later or update the Gemini API billing/quota settings.";
  }

  return `Gemini request failed (${status}): ${message}`;
}

function fileExtensionForMimeType(mimeType: string): string {
  switch (mimeType) {
    case "image/png":
      return "png";
    case "image/webp":
      return "webp";
    case "image/jpeg":
    default:
      return "jpg";
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let input: GenerationRequest;
  try {
    input = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  if (
    !input?.generationId || !input?.mannequinImageUrl || !input?.garmentImageUrl ||
    !input?.prompt
  ) {
    return jsonResponse({ error: "Missing required fields" }, 400);
  }

  const supabase = createSupabaseClient();

  try {
    await updateGeneration(supabase, input.generationId, {
      status: "processing",
      error_message: null,
    });

    const generated = await callGeminiEditAPI(input);
    const extension = fileExtensionForMimeType(generated.mimeType);
    const filePath =
      `${RESULT_FOLDER}/${input.generationId}.${extension}`;

    const { error: uploadError } = await supabase.storage
      .from(RESULT_BUCKET)
      .upload(filePath, generated.bytes, {
        contentType: generated.mimeType,
        upsert: true,
      });

    if (uploadError) {
      throw new Error(`Failed to upload generated image: ${uploadError.message}`);
    }

    const { data: publicUrlData } = supabase.storage
      .from(RESULT_BUCKET)
      .getPublicUrl(filePath);

    await updateGeneration(supabase, input.generationId, {
      status: "completed",
      result_image_url: publicUrlData.publicUrl,
      error_message: null,
    });

    return jsonResponse({
      generationId: input.generationId,
      status: "completed",
      resultImageUrl: publicUrlData.publicUrl,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    try {
      await updateGeneration(supabase, input.generationId, {
        status: "failed",
        error_message: message,
      });
    } catch (_) {
      // Ignore secondary update failures and return the original error.
    }

    return jsonResponse(
      {
        generationId: input.generationId,
        status: "failed",
        error: message,
      },
      500,
    );
  }
});
