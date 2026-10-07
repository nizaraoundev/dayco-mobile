# Google Maps API Key Setup

## 🔑 How to Get Your Google Maps API Key

Your app needs a Google Maps API key to display maps. Follow these steps:

### Step 1: Go to Google Cloud Console
Visit: https://console.cloud.google.com/

### Step 2: Create a New Project (or select existing)
1. Click on the project dropdown at the top
2. Click "New Project"
3. Name it "Dayco Mobile" or similar
4. Click "Create"

### Step 3: Enable Google Maps SDK for Android
1. Go to: https://console.cloud.google.com/apis/library
2. Search for "Maps SDK for Android"
3. Click on it
4. Click "Enable"

### Step 4: Create API Key
1. Go to: https://console.cloud.google.com/apis/credentials
2. Click "+ CREATE CREDENTIALS"
3. Select "API Key"
4. Copy the generated API key

### Step 5: Add API Key to Your App
Open this file:
```
android/app/src/main/AndroidManifest.xml
```

Replace `YOUR_API_KEY_HERE` with your actual API key:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" />
```

### Step 6: Restrict Your API Key (Recommended for Production)
1. In Google Cloud Console, go to your API key
2. Click "Edit API key"
3. Under "Application restrictions", select "Android apps"
4. Click "Add an item"
5. Add your package name: `com.example.dayco_mobile`
6. Get your SHA-1 fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
7. Add the SHA-1 fingerprint
8. Click "Save"

### Step 7: Restart Your App
```bash
flutter clean
flutter run
```

## 💡 For Testing (Free Tier)
Google Maps provides a free tier:
- $200 free credit per month
- Enough for development and testing

## 🚨 Important Notes
- Never commit your API key to public repositories
- Consider using environment variables for production
- Enable billing in Google Cloud (required even for free tier)

## ⚠️ If You See "This API project is not authorized..."
1. Make sure billing is enabled in Google Cloud Console
2. Wait a few minutes for API to activate
3. Check that "Maps SDK for Android" is enabled

## 📱 Alternative for Development Only
If you just want to test without Google Maps:
1. Comment out the map screen navigation
2. Use a simple placeholder page instead

Would you like help with any of these steps?
