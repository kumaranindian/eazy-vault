# Firebase Setup Guide for EazyVault

This guide will help you set up Firebase for the EazyVault application.

## Prerequisites

- Node.js installed (v16 or higher)
- Flutter SDK installed (v3.3.0 or higher)
- A Google account

## Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

## Step 2: Login to Firebase

```bash
firebase login
```

This will open a browser window for you to authenticate with your Google account.

## Step 3: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: **EazyVault**
4. Enable Google Analytics (optional but recommended)
5. Click "Create project"

## Step 4: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

Make sure the Dart global bin directory is in your PATH.

## Step 5: Configure FlutterFire

Run this command in the project root directory:

```bash
flutterfire configure
```

This will:
- List your Firebase projects
- Let you select the EazyVault project
- Generate `firebase_options.dart` file
- Configure platform-specific Firebase settings

Select the following when prompted:
- **Project**: EazyVault
- **Platforms**: Web (select using spacebar, press Enter)

## Step 6: Enable Authentication

1. Go to Firebase Console > Authentication
2. Click "Get started"
3. Enable **Email/Password** sign-in method
4. Enable **Google** sign-in method
   - Add your support email
   - Add authorized domains if needed

## Step 7: Create Firestore Database

1. Go to Firebase Console > Firestore Database
2. Click "Create database"
3. Select "Start in production mode"
4. Choose a location (select closest to your users)
5. Click "Enable"

## Step 8: Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

## Step 9: Deploy Firestore Indexes

```bash
firebase deploy --only firestore:indexes
```

## Step 10: Enable Firebase Storage

1. Go to Firebase Console > Storage
2. Click "Get started"
3. Start in production mode
4. Choose same location as Firestore
5. Click "Done"

## Step 11: Deploy Storage Rules

```bash
firebase deploy --only storage
```

## Step 12: Configure Firebase Hosting (Optional)

```bash
firebase init hosting
```

Select:
- Use existing project: EazyVault
- Public directory: build/web
- Configure as single-page app: Yes
- Set up automatic builds: No
- Don't overwrite index.html

## Step 13: Enable Firebase Analytics (Optional)

1. Go to Firebase Console > Analytics
2. Click "Enable Analytics"
3. Accept terms and conditions

## Step 14: Enable Firebase Crashlytics (Optional)

1. Go to Firebase Console > Crashlytics
2. Click "Enable Crashlytics"
3. Follow the setup instructions

## Step 15: Verify Setup

Run the Flutter app to verify Firebase is configured correctly:

```bash
flutter run -d chrome
```

You should see the app load without Firebase errors.

## Environment-Specific Configuration (Optional)

For production and staging environments:

1. Create separate Firebase projects:
   - EazyVault-Dev
   - EazyVault-Staging
   - EazyVault-Production

2. Run flutterfire configure for each environment

3. Use build flavors to switch between environments

## Security Checklist

- ✅ Firestore rules deployed
- ✅ Storage rules deployed
- ✅ Authentication enabled
- ✅ Email/Password provider enabled
- ✅ Google Sign-In provider enabled
- ✅ Authorized domains configured
- ✅ Firestore indexes created

## Useful Commands

```bash
# Deploy all Firebase resources
firebase deploy

# Deploy only Firestore rules
firebase deploy --only firestore:rules

# Deploy only Storage rules
firebase deploy --only storage

# Deploy only Hosting
firebase deploy --only hosting

# View Firestore data
firebase firestore:indexes

# Check Firebase project
firebase projects:list
```

## Troubleshooting

### Issue: firebase_options.dart not found

**Solution**: Run `flutterfire configure` again

### Issue: Authentication not working

**Solution**: 
1. Check if Email/Password and Google providers are enabled
2. Verify authorized domains in Firebase Console
3. Check browser console for errors

### Issue: Firestore permission denied

**Solution**: 
1. Verify Firestore rules are deployed
2. Check if user is authenticated
3. Verify user ID matches document path

### Issue: Storage upload fails

**Solution**:
1. Check storage rules are deployed
2. Verify file size is under 5MB
3. Check file type is allowed (images, PDF)

## Next Steps

After completing Firebase setup:

1. Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`
2. Test authentication flow
3. Test Firestore operations
4. Test file uploads
5. Deploy to Firebase Hosting

## Support

For issues with Firebase setup:
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Support](https://firebase.google.com/support)

---

**Note**: Keep your `firebase_options.dart` file secure and never commit it to public repositories.
