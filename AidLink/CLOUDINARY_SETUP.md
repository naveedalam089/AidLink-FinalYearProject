# Doctor Verification File Upload Setup

## Overview
Doctor verification documents (CNIC, license, degree, profile photo) are uploaded using **imgbb** (free Cloudinary alternative) since Firebase Storage is not available on the Spark plan.

## Setup Instructions

### Step 1: Create an imgbb Account
1. Go to [imgbb.com](https://imgbb.com)
2. Click "Sign Up" and create a free account
3. Confirm your email

### Step 2: Get Your API Key
1. After logging in, go to [API Settings](https://api.imgbb.com/)
2. Click on "Users" → Your Profile → "API"
3. Copy your **API Key** (it's a long alphanumeric string)

### Step 3: Add API Key to Flutter App
1. Open `lib/views/doctor_mobile/verification_screen.dart`
2. Find this line (around line 120):
   ```dart
   const String imgbbApiKey = 'YOUR_IMGBB_API_KEY_HERE';
   ```
3. Replace `'YOUR_IMGBB_API_KEY_HERE'` with your actual API key:
   ```dart
   const String imgbbApiKey = 'abcdef1234567890xyz...';
   ```

### Step 4: Test Upload
1. Run the app: `flutter run`
2. Go to Doctor Verification Screen
3. Upload a test document (jpg, jpeg, png, or pdf)
4. Verify it uploads successfully

## How It Works

### Upload Flow
1. User picks a file via file picker
2. File is converted to Base64
3. Sent to imgbb API: `https://api.imgbb.com/1/upload`
4. imgbb returns image URL
5. URL is stored in Firestore

### Fallback
If API key is not configured or upload fails:
- File is stored as Base64 data URI in Firestore
- Can be decoded and displayed in app
- Takes up storage space but works offline

## Document Requirements

### File Format
- **Allowed**: JPG, JPEG, PNG, PDF
- **Max Size**: 32MB per file (imgbb limit)

### Documents Required
**At least ONE of these must be uploaded:**
- CNIC Front
- CNIC Back  
- License
- Degree
- Profile Photo

## Troubleshooting

### Upload Fails with 413 Error
- File is too large (>32MB)
- Compress the image/PDF first

### Upload Fails with 401/403 Error
- API key is invalid or expired
- Regenerate API key from imgbb dashboard

### Upload Times Out
- Network connection issue
- Try again with a smaller file
- Check imgbb status at [statuspage.io](https://statuspage.io/)

## Alternative: Use Cloudinary Instead

If you prefer Cloudinary:
1. Go to [cloudinary.com](https://cloudinary.com)
2. Sign up for free account
3. Get your Cloud Name from dashboard
4. Modify code to use Cloudinary API instead of imgbb

The code is already structured to easily switch providers - just modify the `_uploadFile()` method.

## Security Notes

⚠️ **Important**: 
- Do NOT commit API key to git
- Consider moving API key to environment variables
- In production, upload should be handled by backend server
- Use signed URLs for public file access

## For Production

In production environment:
1. Move file uploads to backend server
2. Backend authenticates with imgbb
3. Keeps API key secure
4. Frontend only sends file to backend
5. Backend returns signed URL

This prevents exposing API keys in mobile app source code.
