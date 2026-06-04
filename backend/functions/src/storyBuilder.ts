import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import Anthropic from "@anthropic-ai/sdk";

// Server-side secret — set with: firebase functions:secrets:set ANTHROPIC_API_KEY
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

// Default to the most capable model; override via STORY_MODEL (e.g. claude-sonnet-4-6 for lower cost).
const STORY_MODEL = process.env.STORY_MODEL || "claude-opus-4-8";

// STABLE system prompt — rules, JSON contract, safety. Contains NO per-child data, so the cached
// prefix stays warm across every request/child. The child's vocabulary + story-starter go in the
// USER turn (see below), never here.
const SYSTEM_PROMPT = `You are a gentle storyteller for a child who is just beginning to read.

RULES:
- Use ONLY words from the "ALLOWED WORDS" list given in the user message. Never use any other word.
- Keep each line very short (at most ~8 words) and simple.
- Keep everything wholesome, calm, and age-appropriate for ages 4-7. Absolutely no scary, violent,
  sad, unsafe, or adult content.
- Offer exactly two simple choices to continue, each described using only allowed words.
- Respond with JSON only, matching the provided schema. No extra commentary.`;

// JSON schema the model output must satisfy (structured outputs).
const RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    line: { type: "string" },
    words: { type: "array", items: { type: "string" } },
    choices: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          id: { type: "string" },
          label: { type: "string" },
        },
        required: ["id", "label"],
      },
    },
  },
  required: ["line", "words", "choices"],
} as const;

interface StoryRequest {
  /** The story so far (or a chosen "story starter"). */
  starter?: string;
  /** Content Bank ids / words the child has learned — the vocabulary whitelist. */
  learnedVocab?: string[];
  /** Current curriculum stage (0-4); reserved for orthography hints. */
  stage?: number;
}

interface Choice {
  id: string;
  label: string;
}
interface StorySegment {
  line: string;
  words: string[];
  choices: Choice[];
}

// Safe fallback used when no API key is configured (M0) or anything goes wrong. Only uses the
// most basic seed vocabulary, so it is valid for essentially any learned set.
const CANNED_SEGMENT: StorySegment = {
  line: "I see a pup.",
  words: ["i", "see", "a", "pup"],
  choices: [
    { id: "sun", label: "see the sun" },
    { id: "bee", label: "see a bee" },
  ],
};

function normalizeToken(word: string): string {
  return word.toLowerCase().replace(/[^a-z']/g, "");
}

/** Every word the model emits must be in the child's allowed set. */
function isWithinVocabulary(segment: StorySegment, allowed: Set<string>): boolean {
  const surfaces = [segment.line, ...segment.choices.map((c) => c.label)];
  for (const surface of surfaces) {
    for (const raw of surface.split(/\s+/)) {
      const token = normalizeToken(raw);
      if (token.length > 0 && !allowed.has(token)) return false;
    }
  }
  return true;
}

export const storyBuilder = onCall(
  { secrets: [ANTHROPIC_API_KEY], enforceAppCheck: true, cors: true },
  async (request: CallableRequest<StoryRequest>): Promise<StorySegment> => {
    // AuthN — only signed-in parents' apps may call. App Check is enforced via the option above.
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in to build a story.");
    }

    const { starter = "", learnedVocab = [] } = request.data ?? {};
    const allowed = new Set(learnedVocab.map(normalizeToken).filter(Boolean));

    const apiKey = ANTHROPIC_API_KEY.value();
    if (!apiKey) {
      // M0 stub path: no key configured → return safe, vocabulary-constrained canned content so the
      // whole flow (client → callable → UI) is testable without spending tokens.
      logger.info("storyBuilder: ANTHROPIC_API_KEY not set — returning canned segment (M0 stub).");
      return CANNED_SEGMENT;
    }

    const client = new Anthropic({ apiKey });

    // Per-child, volatile content lives in the USER turn so the cached system prefix stays warm.
    const allowedList = [...allowed].join(", ") || "i, see, a, pup, sun, bee";
    const userMessage = [
      `ALLOWED WORDS (use only these): ${allowedList}`,
      starter ? `STORY SO FAR: ${starter}` : "Begin a brand-new tiny story.",
      "Write the next line and two choices. JSON only.",
    ].join("\n");

    try {
      const message = await client.messages.create({
        model: STORY_MODEL,
        max_tokens: 400,
        // Cache the stable rules/safety/contract; the per-child vocab is in the user turn.
        system: [
          { type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } },
        ],
        messages: [{ role: "user", content: userMessage }],
        // Structured outputs: constrain the response to RESPONSE_SCHEMA. Cast keeps this compiling
        // across SDK minor versions; if the runtime ignores it, the "JSON only" instruction still holds.
        ...({ output_config: { format: { type: "json_schema", schema: RESPONSE_SCHEMA } } } as object),
      });

      const textBlock = message.content.find(
        (b): b is Anthropic.TextBlock => b.type === "text",
      );
      if (!textBlock) {
        logger.warn("storyBuilder: no text block in model response; using canned fallback.");
        return CANNED_SEGMENT;
      }

      const segment = JSON.parse(textBlock.text) as StorySegment;

      // Hard guarantee: nothing outside the child's learned vocabulary reaches the screen.
      if (allowed.size > 0 && !isWithinVocabulary(segment, allowed)) {
        logger.warn("storyBuilder: model produced out-of-vocabulary words; using canned fallback.");
        return CANNED_SEGMENT;
      }

      logger.info("storyBuilder: ok", {
        model: STORY_MODEL,
        cacheReadTokens: message.usage?.cache_read_input_tokens,
        cacheWriteTokens: message.usage?.cache_creation_input_tokens,
      });
      return segment;
    } catch (err) {
      // Never fail open to a child UI — return safe canned content.
      logger.error("storyBuilder: generation failed; using canned fallback.", err);
      return CANNED_SEGMENT;
    }
  },
);
