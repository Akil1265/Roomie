# 🔧 Google Sign-In Fix Instructions

## Problem Identified ✅
Your Google Console has the wrong SHA-1 fingerprint!

**Google Console currently has**: `5c49817871a0e292b5f23650df111ca8da3915bd`
**Your app actually uses**:
- **Release**: `E9:C6:85:E2:71:90:8C:EA:43:99:73:00:94:1D:E2:4F:11:94:84:1F`
- **Debug**: `25:22:9A:8A:06:B0:1B:BC:6A:41:55:D4:82:BC:6B:E8:75:CF:3A:EF`

## Step-by-Step Fix

### 1. Open Google Cloud Console
- Go to: https://console.cloud.google.com/
- Select project: **roomie-cfc03**

### 2. Navigate to Credentials
- Click **APIs & Services** > **Credentials**
- Find your Android OAuth 2.0 client ID
- Click the **edit** (pencil) icon

### 3. Add Both SHA-1 Fingerprints
In the **SHA-1 certificate fingerprints** section, add:

```
E9:C6:85:E2:71:90:8C:EA:43:99:73:00:94:1D:E2:4F:11:94:84:1F
25:22:9A:8A:06:B0:1B:BC:6A:41:55:D4:82:BC:6B:E8:75:CF:3A:EF
```

### 4. Save Changes
- Click **Save**
- Wait 5-10 minutes for Google services to update

### 5. Test Google Sign-In
- Run your app
- Try Google Sign-In
- It should work now! ✅

## Why This Happened
The current SHA-1 (`5c49817871a0e292b5f23650df111ca8da3915bd`) in your Google Console doesn't match either of your actual keystores. This caused the DEVELOPER_ERROR (code 10).

## No Code Changes Needed
Once you update the Google Console with the correct SHA-1 fingerprints, your app will work immediately without any code changes!
