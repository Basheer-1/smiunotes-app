#!/usr/bin/env node
/** Read-only historical credential scan. Never prints matched secret contents. */
import { spawnSync } from "node:child_process";
const git = (args, input) => {
  const r = spawnSync("git", args, {encoding:"utf8", input, maxBuffer:64*1024*1024});
  if (r.status !== 0) throw new Error("Git history unavailable; fetch-depth: 0 is required");
  return r.stdout;
};
const objects = [...new Set(git(["rev-list","--objects","--all"])
  .split("\n").filter(Boolean).map(s=>s.split(" ")[0]))];
const meta = git(["cat-file","--batch-check=%(objectname) %(objecttype) %(objectsize)"],objects.join("\n")+"\n");
const blobs = meta.trim().split("\n").map(s=>s.split(" ")).filter(a=>a[1]==="blob" && Number(a[2]) <= 1024*1024);
const tests = [
  ["android_signing_password", /\b(?:storePassword|keyPassword|SMIUNOTES_RELEASE_(?:STORE|KEY)_PASSWORD)\s*[=:]\s*['"][^'"]{8,}/],
  // Detect PEM contents, not merely a quoted PEM label in source/test fixtures.
  // Full keys include a matching END marker and base64 payload.
  ["private_key", /-----BEGIN ((?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY)-----\s+[A-Za-z0-9+/=\r\n]{80,}-----END \1-----/],
  ["github_token", /\b(?:ghp_|gho_|ghu_|ghs_|github_pat_)[A-Za-z0-9_]{20,}/],
  ["supabase_secret", /\bsb_secret_[A-Za-z0-9_-]{20,}/],
  ["aws_access_key", /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/],
  ["stripe_secret", /\b(?:sk_live_|rk_live_)[A-Za-z0-9]{16,}/],
  ["cloudflare_token", /\b(?:CF_API_TOKEN|CLOUDFLARE_API_TOKEN)\s*[=:]\s*['"]?[A-Za-z0-9_-]{30,}/],
  ["service_role_jwt", /eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g],
];
const hits=[];
for(const [oid] of blobs){
  const data=git(["cat-file","blob",oid]);
  if(data.includes("\0")) continue;
  for(const [type, pattern] of tests){
    pattern.lastIndex=0;
    const match=pattern.exec(data);
    if(!match) continue;
    if(type==="service_role_jwt"){
      try {const payload=JSON.parse(Buffer.from(match[0].split(".")[1],"base64url").toString("utf8"));
        if(payload.role!=="service_role") continue;
      } catch {continue;}
    }
    hits.push({object:oid.slice(0,12),kind:type});
  }
}
console.log(JSON.stringify({status:hits.length?"REVIEW_REQUIRED":"PASS",scannedBlobs:blobs.length,skippedOversizedBlobs:meta.split("\n").filter(s=>/ blob /.test(s)&&Number(s.split(" ")[2])>1024*1024).length,findings:hits},null,2));
if(hits.length) process.exitCode=1;
