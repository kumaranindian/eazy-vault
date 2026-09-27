# 🚀 EazyVault Deployment Guide

## **Production Deployment Instructions**

This guide covers deploying EazyVault to production using Firebase Hosting.

---

## 📋 **Prerequisites**

- ✅ Flutter SDK installed (3.3.0+)
- ✅ Firebase CLI installed
- ✅ Firebase project configured
- ✅ All code generation complete
- ✅ Tests passing

---

## 🔧 **Pre-Deployment Checklist**

### **1. Code Generation**
```bash
# Run code generation
dart run build_runner build --delete-conflicting-outputs

# Verify no errors
flutter analyze
```

### **2. Run Tests**
```bash
# Run all tests
flutter test

# Check test coverage (optional)
flutter test --coverage
```

### **3. Update Version**
Update version in `pubspec.yaml`:
```yaml
version: 1.0.0+1
```

### **4. Environment Configuration**
Ensure Firebase configuration is correct:
- `lib/firebase_options.dart` exists
- `web/index.html` has Google Sign-In client ID
- `firestore.rules` deployed
- `firestore.indexes.json` deployed

---

## 🏗️ **Build for Production**

### **Web Build**
```bash
# Build for web with CanvasKit renderer (better performance)
flutter build web --release --web-renderer canvaskit

# Alternative: HTML renderer (smaller bundle size)
flutter build web --release --web-renderer html

# Build output will be in: build/web/
```

### **Build Configuration**
The build includes:
- ✅ Minified JavaScript
- ✅ Optimized assets
- ✅ Tree-shaken code
- ✅ Compressed resources

---

## 🔥 **Firebase Deployment**

### **1. Initialize Firebase Hosting**
```bash
# Login to Firebase
firebase login

# Initialize hosting (if not already done)
firebase init hosting

# Select options:
# - Public directory: build/web
# - Configure as single-page app: Yes
# - Set up automatic builds: No
# - Overwrite index.html: No
```

### **2. Deploy Firestore Rules**
```bash
# Deploy security rules
firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes
```

### **3. Deploy Web App**
```bash
# Deploy to Firebase Hosting
firebase deploy --only hosting

# Your app will be available at:
# https://YOUR-PROJECT-ID.web.app
# https://YOUR-PROJECT-ID.firebaseapp.com
```

### **4. Custom Domain (Optional)**
```bash
# Add custom domain in Firebase Console
# Then update DNS records as instructed

# Deploy with custom domain
firebase deploy --only hosting
```

---

## 🌐 **Alternative Deployment Options**

### **Option 1: Vercel**
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
cd build/web
vercel

# Follow prompts to configure
```

### **Option 2: Netlify**
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
cd build/web
netlify deploy --prod

# Or use drag-and-drop in Netlify dashboard
```

### **Option 3: GitHub Pages**
```bash
# Build app
flutter build web --release --base-href "/REPO_NAME/"

# Copy build/web to gh-pages branch
# Enable GitHub Pages in repository settings
```

---

## ⚙️ **Post-Deployment Configuration**

### **1. Update OAuth Redirect URLs**
Add your production URL to Firebase Console:
- Go to Authentication → Sign-in method
- Click on Google
- Add authorized domain: `your-domain.com`

### **2. Update CORS Settings**
If using Firebase Storage:
```bash
# Create cors.json
{
  "origin": ["https://your-domain.com"],
  "method": ["GET"],
  "maxAgeSeconds": 3600
}

# Apply CORS
gsutil cors set cors.json gs://YOUR-BUCKET-NAME.appspot.com
```

### **3. Enable Analytics (Optional)**
```bash
# Deploy analytics
firebase deploy --only analytics
```

---

## 🔒 **Security Checklist**

- ✅ Firestore security rules deployed
- ✅ Authentication configured
- ✅ API keys restricted (Firebase Console)
- ✅ HTTPS enabled
- ✅ OAuth redirect URLs updated
- ✅ CORS configured
- ✅ Rate limiting enabled (optional)

---

## 📊 **Monitoring & Maintenance**

### **1. Firebase Console**
Monitor:
- Authentication users
- Firestore usage
- Hosting bandwidth
- Error rates

### **2. Performance Monitoring**
```bash
# Enable performance monitoring
firebase deploy --only performance
```

### **3. Crashlytics (Optional)**
```bash
# Enable crashlytics
firebase deploy --only crashlytics
```

---

## 🔄 **Continuous Deployment**

### **GitHub Actions Example**
Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy to Firebase Hosting

on:
  push:
    branches:
      - main

jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.6'
      
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter test
      - run: flutter build web --release --web-renderer canvaskit
      
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: YOUR-PROJECT-ID
```

---

## 🐛 **Troubleshooting**

### **Build Errors**
```bash
# Clean build
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build web --release
```

### **Firebase Deployment Errors**
```bash
# Check Firebase login
firebase login --reauth

# Check project
firebase projects:list

# Use specific project
firebase use YOUR-PROJECT-ID
```

### **CORS Errors**
- Add domain to Firebase Console → Authentication → Authorized domains
- Update CORS configuration for Storage

### **Loading Issues**
- Check browser console for errors
- Verify Firebase configuration
- Check network tab for failed requests

---

## 📱 **Mobile Deployment (Future)**

### **Android**
```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release

# Upload to Google Play Console
```

### **iOS**
```bash
# Build iOS
flutter build ios --release

# Upload to App Store Connect via Xcode
```

---

## 🎯 **Performance Optimization**

### **1. Enable Caching**
Update `firebase.json`:
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{
      "source": "**",
      "destination": "/index.html"
    }],
    "headers": [{
      "source": "**/*.@(jpg|jpeg|gif|png|svg|webp)",
      "headers": [{
        "key": "Cache-Control",
        "value": "max-age=31536000"
      }]
    }]
  }
}
```

### **2. Enable Compression**
Firebase Hosting automatically compresses files.

### **3. Use CDN**
Firebase Hosting uses Google's CDN automatically.

---

## 📈 **Scaling Considerations**

### **Firestore**
- Monitor read/write operations
- Optimize queries with indexes
- Use pagination for large datasets
- Consider data archiving strategy

### **Authentication**
- Monitor active users
- Set up rate limiting
- Consider quota increases

### **Hosting**
- Monitor bandwidth usage
- Optimize asset sizes
- Use lazy loading
- Implement code splitting

---

## 💰 **Cost Optimization**

### **Firebase Free Tier Limits**
- Firestore: 50K reads, 20K writes per day
- Authentication: Unlimited
- Hosting: 10GB storage, 360MB/day transfer

### **Tips to Stay in Free Tier**
- Use pagination to reduce reads
- Cache data on client side
- Optimize images
- Use CDN caching
- Monitor usage regularly

---

## 🔐 **Backup & Recovery**

### **Firestore Backup**
```bash
# Export Firestore data
gcloud firestore export gs://YOUR-BUCKET/backups

# Import Firestore data
gcloud firestore import gs://YOUR-BUCKET/backups
```

### **Automated Backups**
Set up scheduled exports in Firebase Console:
- Go to Firestore → Import/Export
- Schedule daily/weekly exports

---

## ✅ **Deployment Checklist**

- [ ] Code generation complete
- [ ] Tests passing
- [ ] Version updated
- [ ] Build successful
- [ ] Firestore rules deployed
- [ ] Firestore indexes deployed
- [ ] Web app deployed
- [ ] OAuth URLs updated
- [ ] CORS configured
- [ ] Analytics enabled
- [ ] Monitoring set up
- [ ] Backup strategy in place
- [ ] Documentation updated

---

## 🎉 **Success!**

Your EazyVault app is now live! 🚀

**Next Steps:**
1. Test the production app thoroughly
2. Monitor usage and errors
3. Gather user feedback
4. Plan future enhancements
5. Maintain and update regularly

---

## 📞 **Support**

For issues or questions:
- Check Firebase Console for errors
- Review application logs
- Check Firebase Status page
- Consult Firebase documentation

---

**Happy Deploying!** 🎊
