@echo off
echo Getting SHA-1 fingerprint for current keystore...
echo.

REM Check if Java is available
java -version >nul 2>&1
if %errorlevel% neq 0 (
    echo Java not found in PATH. Trying common Java locations...
    
    REM Try Android Studio's JRE
    if exist "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe" (
        set KEYTOOL="C:\Program Files\Android\Android Studio\jre\bin\keytool.exe"
    ) else if exist "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" (
        set KEYTOOL="C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    ) else (
        echo Please install Java JDK or Android Studio
        pause
        exit /b 1
    )
) else (
    set KEYTOOL=keytool
)

echo Using keytool: %KEYTOOL%
echo.

echo === RELEASE KEYSTORE SHA-1 ===
%KEYTOOL% -list -v -keystore "android\app\release-keystore.jks" -alias release -storepass Akil_1265 -keypass Akil_1265 | findstr SHA1
echo.

echo === DEBUG KEYSTORE SHA-1 ===
%KEYTOOL% -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr SHA1
echo.

echo Copy the SHA-1 fingerprint and add it to Google Cloud Console:
echo 1. Go to https://console.cloud.google.com/
echo 2. Select project: roomie-cfc03
echo 3. APIs ^& Services ^> Credentials
echo 4. Edit the Android OAuth client
echo 5. Add the SHA-1 fingerprint above
echo 6. Save and download new google-services.json
echo.
pause
