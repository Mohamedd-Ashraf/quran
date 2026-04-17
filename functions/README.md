# Cloud Functions for Quraan App

This directory contains Firebase Cloud Functions for the Quraan app.

## Current Functions

### `processDataDeletionRequest`
**Trigger:** Firestore write to `data_deletion_requests/{docId}`

**Purpose:** Automatically process user data deletion requests
- Validate email and request data
- Find user in database
- Delete specified data (bookmarks, wird, history, settings)
- Send confirmation emails to user and admin
- Record deletion status

**Input:**
```json
{
  "email": "user@example.com",
  "dataTypes": ["bookmarks", "history"],
  "reason": "Optional reason",
  "language": "ar",
  "status": "pending",
  "createdAt": "2026-04-16T10:00:00Z"
}
```

**Output:**
```json
{
  "status": "completed",
  "deletedSections": ["bookmarks", "history"],
  "statusUpdatedAt": "2026-04-16T10:00:05Z"
}
```

## Setup

### 1. Install dependencies

```bash
cd functions
npm install
```

### 2. Configure environment variables

Create `functions/.env.local` with:

```
ADMIN_EMAIL=your-admin@gmail.com
ADMIN_EMAIL_PASSWORD=your-app-specific-password
```

**Get Gmail App Password:**
1. Go to https://myaccount.google.com/apppasswords
2. Select "Mail" and "Windows Computer"
3. Copy the 16-character password
4. Paste in `.env.local`

### 3. Test locally (optional)

```bash
firebase emulators:start --only functions
```

The emulator will start at `http://localhost:5001`

### 4. Deploy to Firebase

```bash
# From project root directory
firebase deploy --only functions

# Or specific function
firebase deploy --only "functions:processDataDeletionRequest"
```

### 5. Verify deployment

```bash
# List deployed functions
firebase functions:list

# View logs
firebase functions:log

# Follow logs in real-time
firebase functions:log --follow
```

## Structure

```
functions/
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
├── .env.example          # Environment template
├── .env.local            # NEVER commit (git-ignored)
├── src/
│   └── index.ts          # Main functions
└── lib/                  # Compiled JavaScript (generated)
```

## Scripts

```bash
npm run serve      # Local testing with emulators
npm run deploy     # Deploy to Firebase
npm run logs       # View function logs
npm run shell      # Interactive Firebase shell
```

## Security Notes

⚠️ **Important:**
- `.env.local` contains sensitive credentials - NEVER commit it
- The file is in `.gitignore` for protection
- Store credentials in Firebase environment or secure vault for CI/CD

## Firestore Security Rules

The `data_deletion_requests` collection has strict rules:

```
// Public write only (from web form)
allow create: if [valid email, data types, status=pending]

// No reads from clients
allow read, list, update, delete: if false

// Cloud Admin SDK can do anything
(Server-side only via Cloud Functions)
```

## Troubleshooting

### Functions not deployed?
```bash
firebase functions:list
firebase functions:log | grep error
```

### Emails not sending?
1. Check `.env.local` exists and is valid
2. Verify Gmail App Password is correct
3. Check function logs for errors
4. Ensure sender email has SMTP enabled

### Database not updated?
1. Check Firestore rules allow Cloud Function admin access
2. Verify collection path matches code
3. Check logs for validation errors

## References

- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)
- [Firestore Triggers](https://firebase.google.com/docs/functions/firestore-with-functions)
- [Nodemailer Email Documentation](https://nodemailer.com/)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)

## License

Part of Quraan - Noor Al-Iman mobile app.
