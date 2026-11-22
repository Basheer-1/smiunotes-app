import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const read = (path) => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const workflow = read('.github/workflows/android-signed-release.yml');
const android = read('android/app/build.gradle.kts');
const manifest = read('android/app/src/main/AndroidManifest.xml');
const main = read('lib/main.dart');
const account = read('lib/screens/staging_student_account_page.dart');
const push = read('lib/services/push_registration_api.dart');
const config = read('pubspec.yaml');

export function checkM7ReleaseConfig() {
  const required = [
    [android, 'applicationId = "com.smiunotes.app"', 'Permanent package identity'],
    [android, 'signingConfig = null', 'No debug signing fallback'],
    [workflow, 'workflow_dispatch:', 'Manual release only'],
    [workflow, "environment: android-release", 'Protected release environment'],
    [workflow, "RELEASE_APPROVED", 'Explicit release confirmation'],
    [workflow, "SMIUNOTES_RELEASE_AUTH_ACCEPTED", 'Real auth acceptance'],
    [workflow, "SMIUNOTES_RELEASE_PUSH_ACCEPTED", 'Native push acceptance'],
    [workflow, "flutter analyze", 'Analyzer release gate'],
    [workflow, "flutter test", 'Test release gate'],
    [workflow, "flutter build appbundle --release", 'Signed App Bundle'],
    [workflow, "SMIUNOTES_ENABLE_PRODUCTION_AUTH=true", 'Production mobile login enabled'],
    [manifest, 'android.permission.POST_NOTIFICATIONS', 'Notification permission declaration'],
    [manifest, 'firebase_messaging_auto_init_enabled', 'FCM auto-init guard'],
    [account, "defaultValue: false", 'Native push disabled by default'],
    [push, "this.enabled = false", 'Push API disabled by default'],
    [main, "SMIUNOTES_ENABLE_PRODUCTION_AUTH", 'App uses controlled production login gate'],
    [config, "version:", 'Explicit version in Flutter config'],
  ];
  for (const [file, marker, label] of required) {
    assert.ok(file.includes(marker), 'M7 release gate missing: ' + label);
  }
  assert.match(workflow, /github\.ref == 'refs\/heads\/main'/,
    'A signed release must only run from main');
  assert.match(workflow, /secrets\.SMIUNOTES_RELEASE_KEYSTORE_BASE64/,
    'Signed artifact must use GitHub environment signing secret');
  assert.ok(!/debug\s*\)/.test(android),
    'Production bundle must not silently use debug key');
  console.log('PASS: M7 static release safety preflight');
}
if (process.argv[1] && import.meta.url === new URL('file://' + process.argv[1]).href) {
  checkM7ReleaseConfig();
}
