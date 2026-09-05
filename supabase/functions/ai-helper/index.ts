// =============================================================================
// supabase/functions/ai-helper/index.ts
//
// Server-side proxy to Google's Gemini API for the teacher CMS's AI helper.
// The GEMINI_API_KEY never reaches the client -- it is read from env here
// and used only in the server-to-server call to Gemini.
//
// Request contract (from the Flutter web admin/CMS):
//   POST <functions-url>/ai-helper
//   Authorization: Bearer <supabase user JWT>
//   { mode: 'suggest_lesson_items' | 'generate_practice_prompt' | 'translate_check' | 'free_chat',
//     unit_context?: string,
//     prompt: string }
//
// Response contract (matches the Flutter client's
// `supabase.functions.invoke('ai-helper', body: {...})` usage exactly):
//   200 OK  -> { "text": "<string response>" }
//             For suggest_lesson_items, `text` is a JSON-stringified array
//             of {english_text, filipino_text, accepted_variants} -- it is
//             a plain string field, NOT nested JSON-in-JSON; the CMS UI
//             parses that string with JSON.parse when it needs the array.
//   non-200 -> { "error": "<message>" }
//             The Supabase Dart client throws using response.data as-is on
//             a non-2xx status, so this shape is what the client expects to
//             read the error message from.
//
// Deploying:
//   * Default (recommended): `supabase functions deploy ai-helper`
//     Supabase verifies the caller's JWT before this code ever runs, so a
//     request without a valid Supabase session Authorization header is
//     rejected upstream automatically. This is what you want for a function
//     called by logged-in teachers.
//   * `supabase functions deploy ai-helper --no-verify-jwt`
//     Disables that automatic check -- ONLY use this if you need the
//     function reachable by fully anonymous/unauthenticated callers (not the
//     case here) or you are implementing your own auth scheme. Left as
//     default (JWT verified) is correct for this project.
//
// Secrets:
//   supabase secrets set GEMINI_API_KEY=your-key-here
//
// Dependency-light by design: only native `fetch`, no npm/deno third-party
// SDK for the Gemini call.
// =============================================================================

// Easily swap this if Google promotes a newer default free-tier fast model.
// gemini-1.5-flash is the safe, documented default at time of writing.
const GEMINI_MODEL = "gemini-1.5-flash";
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Mode =
  | "suggest_lesson_items"
  | "generate_practice_prompt"
  | "translate_check"
  | "free_chat";

interface RequestBody {
  mode: Mode;
  unit_context?: string;
  prompt: string;
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// Builds the system instruction sent to Gemini for each CMS "mode". Keeping
// these as plain strings (not a separate config table) since they are part
// of the function's own behavior, not editable content.
function buildSystemInstruction(mode: Mode, unitContext?: string): string {
  const context = unitContext
    ? `The current MATATAG curriculum unit/context is: "${unitContext}".`
    : "";

  switch (mode) {
    case "suggest_lesson_items":
      return [
        "You are a curriculum assistant for a Filipino-language learning app aligned to the Philippine MATATAG curriculum (Filipino / Mother Tongue strand).",
        context,
        "Given a topic, return ONLY a JSON array (no markdown fences, no prose) of 5-10 objects shaped exactly like:",
        '[{"english_text": string, "filipino_text": string, "accepted_variants": string[]}]',
        "accepted_variants should include common alternate spellings and likely speech-recognition (ASR) mis-transcriptions of the Filipino word, lowercase.",
        "Respond with the JSON array and nothing else.",
      ].filter(Boolean).join(" ");

    case "generate_practice_prompt":
      return [
        "You are a friendly Filipino-language tutor for young learners (Kindergarten-Grade 3) following the MATATAG curriculum.",
        context,
        "Given a lesson topic or word, write ONE short, encouraging practice prompt in simple English asking the student to say the Filipino word out loud. Keep it under 2 sentences. Plain text only, no markdown.",
      ].filter(Boolean).join(" ");

    case "translate_check":
      return [
        "You are a Filipino-language accuracy checker for a teacher building curriculum content.",
        context,
        "You will be given an English/Filipino word or phrase pair. Verify the Filipino translation is accurate and age-appropriate for young learners.",
        'Respond in plain text: start with either "Correct." or "Needs correction:" followed by the corrected Filipino text and a one-sentence explanation.',
      ].filter(Boolean).join(" ");

    case "free_chat":
    default:
      return [
        "You are a helpful assistant embedded in a teacher's CMS for a gamified Filipino-language learning app (MATATAG curriculum, Filipino / Mother Tongue strand).",
        context,
        "Answer the teacher's question directly and concisely in plain text.",
      ].filter(Boolean).join(" ");
  }
}

async function callGemini(apiKey: string, systemInstruction: string, prompt: string) {
  const payload = {
    system_instruction: {
      parts: [{ text: systemInstruction }],
    },
    contents: [
      {
        role: "user",
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: {
      temperature: 0.4,
      maxOutputTokens: 1024,
    },
  };

  const res = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  const data = await res.json().catch(() => null);

  if (!res.ok) {
    const message = data?.error?.message ?? `Gemini upstream error (HTTP ${res.status})`;
    throw new Error(message);
  }

  const text: string | undefined =
    data?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ??
    undefined;

  if (!text) {
    throw new Error("Gemini returned no usable text in its response.");
  }

  return text;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed. Use POST." });
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    // Missing server config -- never a client error, so 500.
    return jsonResponse(500, {
      error: "GEMINI_API_KEY is not configured on the server. Run `supabase secrets set GEMINI_API_KEY=...`.",
    });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "Request body must be valid JSON." });
  }

  const validModes: Mode[] = [
    "suggest_lesson_items",
    "generate_practice_prompt",
    "translate_check",
    "free_chat",
  ];

  if (!body || typeof body.prompt !== "string" || body.prompt.trim() === "") {
    return jsonResponse(400, { error: "`prompt` is required and must be a non-empty string." });
  }

  if (!body.mode || !validModes.includes(body.mode)) {
    return jsonResponse(400, {
      error: `\`mode\` must be one of: ${validModes.join(", ")}.`,
    });
  }

  const systemInstruction = buildSystemInstruction(body.mode, body.unit_context);

  try {
    const text = await callGemini(apiKey, systemInstruction, body.prompt);
    return jsonResponse(200, { text });
  } catch (err) {
    // Upstream/network failure -- surface as 502 (bad gateway) since our
    // server is fine, the dependency we called is what failed.
    const message = err instanceof Error ? err.message : "Unknown error calling Gemini.";
    return jsonResponse(502, { error: message });
  }
});
