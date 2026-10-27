# Along — Firebase setup (Spark plan)

The app uses Firebase Authentication and Cloud Firestore. Group creation,
owner-approved join requests, member removal, saved places, and geofence
activity use the iOS Firestore SDK and do not require Cloud Functions.

## 1. Firebase project and iOS app

1. Create a project in the [Firebase Console](https://console.firebase.google.com).
2. Register an iOS app with bundle ID **`com.praveen.assignment`**.
3. Download `GoogleService-Info.plist` and add it to the `assignment/` app
   target in Xcode.
4. Enable **Authentication → Email/Password**.
5. Create a **Cloud Firestore** database.

## 2. Deploy Firestore rules and indexes

Install the Firebase CLI if needed, then from this repository's `backend/`
directory:

```bash
firebase login
firebase use --add
firebase deploy --only firestore:rules,firestore:indexes
```

Choose the same Firebase project used by the iOS plist. The rules let users
create groups, submit join requests using a shared group ID, and let only the
group owner approve or reject requests. Members can enable location sharing;
each member's location writes are restricted to their own document.

## 3. Owner-approved group joining

The group creator shares the group ID from the group details. A signed-in user
enters that ID and submits a request. The owner approves or rejects pending
requests in group details. Approved members are added with sharing disabled;
each person must turn location sharing on for themselves.

Group creation and approval run as atomic client writes protected by Firestore
rules. The app does not call the legacy invite Cloud Functions for this flow.

## 4. Geofencing and notifications

Saved-place geofencing and local notifications work on device after the user
grants location and notification permissions. Each device monitors its own
geofence transitions.

Remote push delivery to other members is not implemented. FCM tokens are
collected by the app, but a trusted server-side send path is needed to deliver
push messages. Deploying Firebase Cloud Functions requires the Blaze plan.

## 5. Optional emulators

From `backend/`:

```bash
firebase emulators:start
```

The iOS app is not currently configured to connect to the local emulators.
