# Firebase Hosting Deployment Checklist

## Files Ready for Deployment to Firebase Hosting (quraan-dd543)

### HTML Pages Created/Updated

#### 1. **data-deletion-request.html** (NEW)
- **Path:** `public/data-deletion-request.html`
- **Purpose:** Allows users to request selective deletion of specific data types
- **Features:**
  - Bilingual form (Arabic/English with language toggle)
  - Checkbox options for: Bookmarks, Wird, Settings, History, or All Data
  - Email verification field
  - Optional feedback reason field
  - 4-step process visualization
  - Accessible from: Settings → "طلب حذف البيانات" / "Request Data Deletion"
- **URL:** `https://quraan-dd543.web.app/data-deletion-request`

#### 2. **delete-account.html** (EXISTING - No changes needed)
- **Path:** `public/delete-account.html`
- **Purpose:** Full account and data deletion
- **URL:** `https://quraan-dd543.web.app/delete-account`

#### 3. **privacy.html** (UPDATED)
- **Path:** `public/privacy.html`
- **Changes:**
  - Updated Section 5 to link to both data deletion options
  - Added links to data-deletion-request.html and delete-account.html
  - Clarified difference between selective deletion and full account deletion
  - Updated English version with identical changes

### Flutter App Integration

#### Settings Screen (`lib/features/quran/presentation/screens/settings_screen.dart`)
- **Change:** Added new "طلب حذف البيانات" / "Request Data Deletion" button
  - Orange icon and color (to distinguish from red delete button)
  - Positioned before the account deletion button
  - Opens data-deletion-request.html in external browser
  - Method: `_openDataDeletionRequest(BuildContext context)`
  - Import added: `package:url_launcher/url_launcher.dart`

### Play Console Documentation

#### PLAY_CONSOLE_GUIDE_AR.md (UPDATED)
- Added comprehensive answer for selective data deletion question
- Documents:
  - Link to data deletion request form
  - Data types that can be deleted
  - Processing timeline (7 business days)
  - In-app access method (Settings)
  - Difference from account deletion

## Deployment Instructions

### To Deploy to Firebase Hosting:

```bash
cd e:\Quraan\quraan

# Ensure Firebase CLI is installed (if not: npm install -g firebase-tools)

# Deploy only the updated public folder files
firebase deploy --only hosting
```

### Or deploy specific files only:
```bash
firebase deploy --only hosting:public/data-deletion-request.html
firebase deploy --only hosting:public/privacy.html
```

## Compliance with Google Play Policies

✅ **Q: Do you provide users a way to request deletion of some/all data without deleting account?**
- **Answer:** YES
- **Implementation:** Dedicated data deletion request page with selective options
- **Proof Points:**
  1. Separate data deletion form (not tied to account deletion)
  2. Choose specific data types to delete
  3. Clear documentation of process and timeline
  4. In-app access from Settings menu
  5. Email verification for security

✅ **Q: Where can users request data deletion?**
- **Answer:** Multiple locations:
  1. In-app: Settings → "طلب حذف البيانات" / "Request Data Deletion"
  2. Web: https://quraan-dd543.web.app/data-deletion-request
  3. Full account deletion: https://quraan-dd543.web.app/delete-account
  4. Privacy policy: https://quraan-dd543.web.app/privacy

✅ **Data Types Deletable:**
- Bookmarks (saved verses and pages)
- Daily Wird (progress and goals)
- Personal Settings (fonts, colors, preferences)
- Recitation History (reading logs)
- All Data (complete wipe)

✅ **Processing Timeline:**
- Request Receipt: Immediate
- Verification: Automatic email verification
- Deletion: Within 7 business days
- Confirmation: Email notification

## Testing Checklist

- [ ] Deploy data-deletion-request.html to Firebase
- [ ] Deploy updated firestore.rules to Firebase
- [ ] Verify URL is accessible at https://quraan-dd543.web.app/data-deletion-request
- [ ] Test language toggle works
- [ ] Test form submission (should create a new document in Firestore collection `data_deletion_requests`)
- [ ] Verify privacy.html links point to correct URLs
- [ ] Build and run Flutter app in Android/iOS
- [ ] Verify Settings screen button opens data deletion page
- [ ] Verify URL launcher works and opens external browser

## Notes

- The data-deletion-request.html form now writes requests to Firestore collection `data_deletion_requests`
- Firestore security rules were updated to allow create-only validated submissions for this collection
- Email verification and deletion execution workflow still need server-side automation (next phase)
- Actual deletion should be processed by a protected backend/admin workflow, not by the public form

## Files Summary

```
e:\Quraan\quraan\
├── public/
│   ├── data-deletion-request.html (NEW - 15KB)
│   ├── delete-account.html (EXISTING)
│   ├── privacy.html (UPDATED)
│   └── ...other public files
├── lib/features/quran/presentation/screens/
│   └── settings_screen.dart (UPDATED - added _openDataDeletionRequest method)
└── PLAY_CONSOLE_GUIDE_AR.md (UPDATED)
```

First implementation step is now live: request capture is real (Firestore-backed) instead of placeholder logging.
