#!/usr/bin/env node
/**
 * Release-only public API smoke. No credentials are used or printed.
 * Fail closed on HTML/Vercel protection, unexpected responses, or redirects.
 * Usage: node scripts/check-release-api.mjs
 */
const allowedOrigin = "https://smiunotes.com";
const configured = process.env.SMIUNOTES_RELEASE_API_BASE;
if (configured !== allowedOrigin) {
  console.error("BLOCKED: production API origin must exactly match the approved host.");
  process.exit(2);
}
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 12000);
async function jsonGet(path) {
  const result = await fetch(allowedOrigin + path, {
    redirect: "manual",
    headers: { Accept: "application/json" },
    signal: controller.signal,
  });
  if (result.status >= 300 && result.status < 400) {
    throw new Error("Unexpected API redirect; possible access protection.");
  }
  const type = result.headers.get("content-type") ?? "";
  if (!type.toLowerCase().includes("application/json")) {
    throw new Error("Endpoint returned non-JSON content.");
  }
  const length = result.headers.get("content-length");
  if (length !== null && Number(length) > 131072) {
    throw new Error("API response exceeded maximum size.");
  }
  const reader = result.body?.getReader();
  if (!reader) throw new Error("API response body unavailable.");
  const chunks = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > 131072) {
      await reader.cancel();
      throw new Error("API response exceeded maximum size.");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  const data = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  return { status: result.status, data };
}
try {
  const auth = await jsonGet("/api/mobile/v1/auth");
  if (auth.status !== 200 || auth.data?.enabled !== true) {
    throw new Error("Mobile authentication endpoint is not enabled.");
  }
  console.log("PASS production mobile auth readiness");
  const notes = await jsonGet("/api/mobile/v1?kind=notes");
  if (notes.status !== 200 || !Array.isArray(notes.data?.items)) {
    throw new Error("Public mobile notes API is not returning a valid feed.");
  }
  console.log("PASS public mobile notes feed");
  const guestInbox = await jsonGet("/api/mobile/v1/notifications");
  if (guestInbox.status !== 401) {
    throw new Error("Guest notification access must return HTTP 401.");
  }
  console.log("PASS unauthenticated inbox is denied");
} catch (error) {
  console.error("BLOCKED release API smoke:", error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
} finally {
  clearTimeout(timeout);
}
