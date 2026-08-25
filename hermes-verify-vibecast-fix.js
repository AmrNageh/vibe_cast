const fs = require('fs');
const path = require('path');

console.log('=== Verifying VibeCast Walkie-Talkie Fixes ===\n');

// 1. Check walkie_talkie_bloc.dart fixes
const blocPath = 'D:/Project-CRM/vibe_cast/lib/features/walkie_talkie/bloc/walkie_talkie_bloc.dart';
console.log(`Checking ${blocPath}`);
if (!fs.existsSync(blocPath)) {
  console.log('❌ ERROR: File not found');
  process.exit(1);
}

const blocContent = fs.readFileSync(blocPath, 'utf8');

// Check for fixed _onPTTPressed method (should not have the problematic conditional)
// We look for the listen call with the function syntax (not arrow)
const hasFixedPTTPressed = blocContent.includes('_audioCaptureSub = _audioCaptureService.audioStream.listen((data) {') 
  && !blocContent.includes('if (state is WalkieTalkieInChannel && (state as WalkieTalkieInChannel).status == TransmissionStatus.transmitting)');

console.log(`✓ _onPTTPressed fixed (no conditional blocking audio subscription): ${hasFixedPTTPressed}`);

// Check for audio session configuration in _onInitialized
const hasAudioSessionConfig = blocContent.includes('await session.configure(AudioSessionConfiguration(') 
  && blocContent.includes('avAudioSessionCategory: AVAudioSessionCategory.playAndRecord')
  && blocContent.includes('androidAudioAttributes: AndroidAudioAttributes(')
  && blocContent.includes('usage: AndroidAudioUsage.voiceCommunication');

console.log(`✓ Audio session configuration added: ${hasAudioSessionConfig}`);

// 2. Check APK files
const apkDir = 'D:/Project-CRM/vibe_cast/build/app/outputs/flutter-apk';
console.log(`\nChecking APKs in ${apkDir}`);
if (!fs.existsSync(apkDir)) {
  console.log('❌ ERROR: APK directory not found');
  process.exit(1);
}

const apkFiles = fs.readdirSync(apkDir).filter(f => f.endsWith('.apk'));
console.log(`Found ${apkFiles.length} APK files:`);

let allApksValid = true;
for (const apk of apkFiles) {
  const apkPath = path.join(apkDir, apk);
  const stats = fs.statSync(apkPath);
  const sizeMB = (stats.size / (1024 * 1024)).toFixed(1);
  const isValid = stats.size > 1000000; // At least 1MB
  console.log(`  ${apk}: ${sizeMB} MB ${isValid ? '✓' : '❌'}`);
  if (!isValid) allApksValid = false;
}

// 3. Check that app-release.apk exists (the universal apk)
const universalApkPath = path.join(apkDir, 'app-release.apk');
const hasUniversalApk = fs.existsSync(universalApkPath);
console.log(`\n✓ Universal APK (app-release.apk) exists: ${hasUniversalApk}`);

// Summary
console.log('\n=== VERIFICATION SUMMARY ===');
console.log(`PTT Fix Applied: ${hasFixedPTTPressed ? 'YES' : 'NO'}`);
console.log(`Audio Session Config: ${hasAudioSessionConfig ? 'YES' : 'NO'}`);
console.log(`APKs Built Valid: ${allApksValid ? 'YES' : 'NO'}`);
console.log(`Universal APK Present: ${hasUniversalApk ? 'YES' : 'NO'}`);

const allChecksPass = hasFixedPTTPressed && hasAudioSessionConfig && allApksValid && hasUniversalApk;
console.log(`\nOVERALL: ${allChecksPass ? '✅ ALL CHECKS PASSED' : '❌ SOME CHECKS FAILED'}`);

if (!allChecksPass) {
  process.exit(1);
}