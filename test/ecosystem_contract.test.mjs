import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { validateContract, compareContracts } from "../scripts/check-ecosystem-contract.mjs";

const supported = JSON.parse(readFileSync(
  new URL("../config/mobile-contract-v1.json", import.meta.url), "utf8"));
const clone = () => structuredClone(supported);

test("Android has explicit native student feature support and safe policies", () => {
  assert.equal(validateContract(supported).features.length, 14);
  assert.equal(compareContracts(clone(), supported), true);
});

test("A new web student feature blocks parity until Android is updated", () => {
  const site = clone();
  site.revision++;
  site.features.push("student_timetable");
  assert.throws(() => compareContracts(site, supported), /parity drift/);
});

test("A new web API endpoint must be reviewed for Android", () => {
  const site = clone();
  site.endpoints.push("/api/mobile/v1/calendar");
  assert.throws(() => compareContracts(site, supported), /parity drift/);
});

test("Never silently relax account or notifications rules", () => {
  const site = clone();
  site.policies.account_actions_require_login = false;
  assert.throws(() => compareContracts(site, supported), /permission and alert policies/);
});

test("Missing or malformed manifests are not accepted", () => {
  assert.throws(() => validateContract({}), /schema/);
  const duplicate = clone();
  duplicate.features.push("public_notes");
  assert.throws(() => validateContract(duplicate), /unique stable identifiers/);
});
