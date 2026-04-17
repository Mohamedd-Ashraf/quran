# Data Deletion Implementation Plan

## Step List

- [x] Step 1: Connect the public deletion request form to a real backend write path.
  - Integrated [public/data-deletion-request.html](public/data-deletion-request.html) with Firebase Firestore.
  - Replaced placeholder `console.log` submission flow with real `addDoc(...)` writes.
  - Added client-side submit lock + clearer success/error handling.
  - Added Firestore rule for `data_deletion_requests` create-only submissions with basic validation.

- [ ] Step 2: Build admin processing workflow.
  - Add an internal dashboard/flow to review pending requests.
  - Add statuses: `pending`, `verified`, `completed`, `rejected`.

- [ ] Step 3: Implement actual selective deletion executor.
  - Delete by requested scope (`bookmarks`, `wird`, `settings`, `history`, `all`).
  - Record completion timestamps and operator metadata.

- [ ] Step 4: Add user confirmation and audit trail.
  - Send confirmation email after completion.
  - Keep immutable audit entries for compliance.

- [ ] Step 5: Final policy alignment and release checks.
  - Align Privacy Policy + Play Console Data Safety text with actual behavior.
  - Run end-to-end tests (submit -> verify -> execute -> confirm).
