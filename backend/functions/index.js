const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");

initializeApp();
const db = getFirestore();

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
const INVITE_USAGE_LIMIT = 10;

function generateCode() {
  // 8 uppercase hex characters, e.g. "9F3A2C1B"
  return crypto.randomBytes(4).toString("hex").toUpperCase();
}

function hashCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return request.auth.uid;
}

async function requireMember(groupId, uid) {
  const memberSnap = await db
    .collection("groups").doc(groupId)
    .collection("members").doc(uid).get();
  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "You are not a member of that group.");
  }
  return memberSnap;
}

/**
 * createGroupInvite({ groupId }) -> { code, expiresAt }
 * Creates a single-use tracked invitation. Only a SHA-256 hash of the code is
 * stored; the plaintext code is returned once to the caller.
 */
exports.createGroupInvite = onCall(async (request) => {
  const uid = requireAuth(request);
  const groupId = request.data?.groupId;
  if (typeof groupId !== "string" || groupId.length === 0) {
    throw new HttpsError("invalid-argument", "groupId is required.");
  }
  await requireMember(groupId, uid);

  const code = generateCode();
  const expiresAt = new Date(Date.now() + INVITE_TTL_MS);
  await db.collection("groups").doc(groupId).collection("invitations").add({
    codeHash: hashCode(code),
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt,
    usageLimit: INVITE_USAGE_LIMIT,
    usageCount: 0,
    active: true,
  });

  return { code, expiresAt: Math.floor(expiresAt.getTime() / 1000) };
});

/**
 * redeemGroupInvite({ code }) -> { groupId, groupName }
 * Atomically validates the invite, adds the caller as a member, increments
 * usage and appends a memberJoined event — all inside one transaction.
 */
exports.redeemGroupInvite = onCall(async (request) => {
  const uid = requireAuth(request);
  const rawCode = request.data?.code;
  if (typeof rawCode !== "string" || !/^[A-Z0-9]{8}$/.test(rawCode.trim().toUpperCase())) {
    throw new HttpsError("invalid-argument", "Invalid invite code format.");
  }
  const code = rawCode.trim().toUpperCase();

  const inviteQuery = await db.collectionGroup("invitations")
    .where("codeHash", "==", hashCode(code))
    .where("active", "==", true)
    .limit(1)
    .get();

  if (inviteQuery.empty) {
    throw new HttpsError("not-found", "That invite code is invalid or has expired.");
  }

  const inviteDoc = inviteQuery.docs[0];
  const groupRef = inviteDoc.ref.parent.parent;
  if (!groupRef) {
    throw new HttpsError("internal", "Malformed invitation.");
  }

  const displayName = request.auth.token.name
    || request.auth.token.email
    || "Member";

  return db.runTransaction(async (tx) => {
    const [inviteSnap, groupSnap, memberSnap] = await Promise.all([
      tx.get(inviteDoc.ref),
      tx.get(groupRef),
      tx.get(groupRef.collection("members").doc(uid)),
    ]);

    if (!groupSnap.exists) {
      throw new HttpsError("not-found", "That group no longer exists.");
    }
    const invite = inviteSnap.data();
    if (!invite?.active) {
      throw new HttpsError("not-found", "That invite code is invalid or has expired.");
    }
    if (invite.expiresAt && invite.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("not-found", "That invite code has expired.");
    }
    if (invite.usageCount >= invite.usageLimit) {
      throw new HttpsError("resource-exhausted", "That invite has reached its usage limit.");
    }
    if (memberSnap.exists) {
      throw new HttpsError("already-exists", "You are already a member of that group.");
    }

    tx.update(inviteDoc.ref, {
      usageCount: FieldValue.increment(1),
      active: invite.usageCount + 1 < invite.usageLimit,
    });
    tx.set(groupRef.collection("members").doc(uid), {
      role: "member",
      displayName,
      joinedAt: FieldValue.serverTimestamp(),
      sharingEnabled: false,
    });
    tx.update(groupRef, {
      memberIds: FieldValue.arrayUnion(uid),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(groupRef.collection("events").doc(), {
      type: "memberJoined",
      memberUid: uid,
      memberName: displayName,
      timestamp: FieldValue.serverTimestamp(),
      source: "server",
      deduplicationKey: `join_${inviteDoc.id}_${uid}`,
    });

    return { groupId: groupRef.id, groupName: groupSnap.data().name };
  });
});

/**
 * cleanupGroupDocuments — removes subcollections when a group doc is deleted
 * so events/places/invitations don't linger as orphans.
 */
exports.cleanupGroupDocuments = onDocumentDeleted("groups/{groupId}", async (event) => {
  const groupRef = event.data?.ref;
  if (!groupRef) return;
  for (const sub of ["members", "locations", "savedPlaces", "events", "invitations"]) {
    const snap = await groupRef.collection(sub).get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
});
