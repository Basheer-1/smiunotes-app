#!/usr/bin/env node
/**
 * SMIUNotes ecosystem contract guard.
 * --local: validate the Android supported feature contract offline.
 * --remote: compare the published website contract with this Android build.
 * Never sends user IDs, tokens, receipts or application secrets.
 */
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const allowedOrigin = "https://smiunotes.com";
const localPath = new URL("../config/mobile-contract-v1.json", import.meta.url);
const requiredFields = [
  "public_notes", "public_updates", "public_community",
  "contributors_directory", "student_auth", "student_profile",
  "student_verification", "study_library", "support", "contact",
  "notifications", "notification_preferences", "profile_settings",
  "public_policies",
];

export function validateContract(raw) {
  assert.ok(raw && typeof raw === "object" && !Array.isArray(raw),
    "Invalid ecosystem contract object");
  assert.equal(raw.schema, "smiunotes.mobile-contract.v1",
    "Invalid ecosystem contract schema");
  assert.ok(Number.isSafeInteger(raw.revision) && raw.revision >= 1,
    "Revision must be a positive integer");
  assert.equal(raw.api_base, "/api/mobile/v1");
  assert.equal(raw.minimum_android_contract, 1);
  assert.ok(Array.isArray(raw.features) &&
    raw.features.every(x => /^[a-z_]{3,48}$/.test(x)) &&
    new Set(raw.features).size === raw.features.length,
    "Feature list must contain unique stable identifiers");
  for (const feature of requiredFields) {
    assert.ok(raw.features.includes(feature),
      "Required Android capability missing: " + feature);
  }
  assert.ok(Array.isArray(raw.endpoints) &&
    raw.endpoints.length >= 10 &&
    raw.endpoints.every(x => typeof x === "string" &&
      x.startsWith("/api/mobile/v1") && !x.includes("..")) &&
    new Set(raw.endpoints).size === raw.endpoints.length,
    "Invalid endpoint map");
  assert.ok(raw.policies && typeof raw.policies === "object" &&
    raw.policies.public_browsing === true &&
    raw.policies.account_actions_require_login === true &&
    raw.policies.account_identity_server_owned === true &&
    raw.policies.admin_contributor_editor_dashboards_in_app === false &&
    raw.policies.notes_broadcast_push === false,
    "Consumer permission and alert policies differ");
  return raw;
}

export function compareContracts(website, android) {
  validateContract(website);
  validateContract(android);
  if (website.minimum_android_contract > android.minimum_android_contract) {
    throw new Error("Website requires a newer Android contract version.");
  }
  const newFeatures = website.features.filter(f => !android.features.includes(f));
  const newEndpoints = website.endpoints.filter(p => !android.endpoints.includes(p));
  if (newFeatures.length || newEndpoints.length) {
    throw new Error("Ecosystem parity drift: website has unreviewed features (" +
      newFeatures.join(", ") + ") or endpoints (" + newEndpoints.join(", ") +
      "). Update and test the native Flutter app before marking parity.");
  }
  for (const [key, value] of Object.entries(website.policies)) {
    if (android.policies[key] !== value) {
      throw new Error("Ecosystem parity drift in policy: " + key);
    }
  }
  return true;
}

async function remoteContract() {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(allowedOrigin + "/mobile-contract/v1.json", {
      method: "GET", redirect: "error", signal: controller.signal,
      headers: { Accept: "application/json" },
    });
    if (!response.ok) {
      throw new Error("Website contract endpoint HTTP " + response.status);
    }
    if (!(response.headers.get("content-type") ?? "")
      .toLowerCase().includes("application/json")) {
      throw new Error("Website contract returned HTML, not JSON.");
    }
    const bytes = await response.arrayBuffer();
    if (bytes.byteLength > 16384) throw new Error("Website contract too large.");
    return JSON.parse(new TextDecoder("utf-8", { fatal: true })
      .decode(bytes));
  } finally {
    clearTimeout(timeout);
  }
}

if (process.argv[1] && import.meta.url === new URL(
  "file://" + process.argv[1]).href) {
  try {
    const android = validateContract(JSON.parse(readFileSync(localPath, "utf8")));
    if (process.argv.includes("--remote")) {
      const website = await remoteContract();
      compareContracts(website, android);
      console.log("PASS: published website capabilities match Android's supported contract");
    } else {
      console.log("PASS: Android ecosystem contract validated offline");
    }
  } catch (error) {
    console.error("BLOCKED: " + (error?.message ?? String(error)));
    process.exitCode = 1;
  }
}
