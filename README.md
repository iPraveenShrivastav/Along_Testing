# Along

Along is an iOS app for sharing a group’s locations and keeping track of places that matter to the group. It is built with SwiftUI, MapKit, Core Location, and Firebase.

## What works in the app

- Create an account and sign in with Firebase Authentication.
- Create a group, request to join another group, and let the group owner approve or reject requests.
- Share a member’s location with the group when that member enables sharing.
- Add saved places with a map location and radius.
- Monitor saved-place arrival and departure on the device and show local notifications when permission is granted.
- View group activity recorded by the app.

## Open and run

1. Open `assignment.xcodeproj` in Xcode.
2. In Firebase Console, register an iOS app with bundle ID `com.praveen.assignment`.
3. Enable Email/Password sign-in and create a Cloud Firestore database.
4. Download that app’s `GoogleService-Info.plist` and add it to the `assignment` app target in Xcode. The file is intentionally ignored by Git; each developer should get it from the Firebase project they use.
5. Select the `assignment` app scheme, choose an iPhone simulator or a connected iPhone, and run.

Location sharing and geofence alerts need location permission. Local notifications need notification permission. A physical iPhone is recommended when checking geofence behavior.

## Firestore setup

The Firestore rules and composite index are in `backend/`. From the repository root, select the Firebase project for this app and deploy the rules and index:

```bash
cd backend
firebase use --add
firebase deploy --only firestore:rules,firestore:indexes
```

Use the same Firebase project that provided `GoogleService-Info.plist`. Keep the project selection pointed at the intended project before deploying.

The current group flow uses Firestore directly: members submit join requests, and an owner approves or rejects them. This flow does not need Cloud Functions. The `backend/functions` folder contains the older invite-code and cleanup functions; they are not used by the current owner-approval flow. Deploying those Firebase Functions requires the Blaze plan.

The emulator configuration is in `backend/firebase.json`. The iOS app is not currently configured to connect to the local emulators.

## Notifications

### Local notifications

Saved-place arrival and departure alerts are handled on the iPhone using Core Location and User Notifications. They do not need a server. The app also has an immediate local notification for a newly saved place when notifications are enabled.

### Remote push notifications

Remote push delivery to other group members is not finished yet. The app already obtains an FCM registration token and saves it under the signed-in user’s `fcmTokens` field in Firestore. That token lets a trusted sender address a device; it does not send a push by itself.

The planned sender is a small Node.js HTTPS service hosted on Render, using Firebase Admin SDK and Firebase Cloud Messaging. That service is not in this repository yet, and the app does not currently call it. To complete remote push:

1. Enable the Push Notifications capability for the iOS app and upload an APNs authentication key to the matching Firebase project.
2. Build a Node.js service that verifies the caller’s Firebase Authentication ID token, checks that the caller belongs to the group, and sends a message through Firebase Admin Messaging to the other members’ saved FCM tokens.
3. Store the Firebase service-account credentials as a private Render environment secret. Never add them to the iOS app, the repository, or GitHub.
4. Add an authenticated HTTPS call from the app when a relevant group event occurs. Validate the group and event on the server, avoid sending the notification back to the person who caused the event, and remove expired FCM tokens when Firebase reports them as invalid.
5. Test on physical iPhones with notifications allowed and verify that the Firebase project, APNs key, app bundle ID, and signing configuration all match.

The app’s current Firestore event writes do not trigger Render automatically. The HTTPS call in step 4, or another server-side event delivery mechanism, must be implemented before group members receive remote notifications. Render hosting does not remove the need to protect the endpoint and its credentials.

## Repository notes

`GoogleService-Info.plist`, Xcode user data, build output, local Firebase state, Node dependencies, and common signing or service-account credentials are excluded by `.gitignore`. Commit the Firebase rules, indexes, `firebase.json`, and Node package lockfile so the project setup can be reproduced.

Do not commit APNs `.p8` keys, Firebase Admin service-account files, FCM device tokens copied from logs, or other private credentials.
