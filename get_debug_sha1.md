# Google Sign-In Debug Configuration Fix

## Problem
Google Sign-In is failing with error code 10 (DEVELOPER_ERROR) because the SHA-1 fingerprint in Google Console doesn't match the debug keystore being used.

## Current Setup
- Package name: `com.example.roomie`
- Release SHA-1 registered: `5c49817871a0e292b5f23650df111ca8da3915bd`
- Debug keystore location: `C:\Users\Akil\.android\debug.keystore`

## Solution Steps

### 1. Get Debug SHA-1 Fingerprint
Open Command Prompt (not PowerShell) and run:
```cmd
cd "C:\Program Files\Android\Android Studio\jre\bin"
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Alternative if Android Studio JRE is not available:
```cmd
cd "C:\Program Files\Java\jdk-XX.X.X\bin"
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Look for the **SHA1** fingerprint in the output.

### 2. Add SHA-1 to Google Console
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `roomie-cfc03`
3. Go to **APIs & Services** > **Credentials**
4. Find the OAuth 2.0 client ID for Android
5. Click **Edit**
6. Add the debug SHA-1 fingerprint to the **SHA-1 certificate fingerprints** list
7. Save the changes

### 3. Download Updated google-services.json
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select `roomie-cfc03` project
3. Go to **Project Settings** > **General**
4. Scroll down to **Your apps**
5. Click the **Android app**
6. Download the updated `google-services.json`
7. Replace the current file in `android/app/google-services.json`

### 4. Clean and Rebuild
```bash
flutter clean
flutter pub get
flutter run
```

## Alternative Quick Fix
If you want to use the existing release keystore for debug builds too, you can keep the current configuration. However, using the debug keystore is recommended for development.

## Testing
After making these changes, Google Sign-In should work without the error code 10.
