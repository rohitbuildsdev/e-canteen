const {setGlobalOptions} = require('firebase-functions');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();
const auth = getAuth();
setGlobalOptions({region: 'asia-south1', maxInstances: 10});

function normalizeRegistrationNumber(value) {
  if (typeof value !== 'string') throw new HttpsError('invalid-argument', 'Enter your registration number.');
  const regNo = value.trim().toLowerCase();
  if (!/^[a-z0-9._-]{3,30}$/.test(regNo)) throw new HttpsError('invalid-argument', 'Invalid registration number.');
  return regNo;
}
function studentEmail(regNo) { return `student_${regNo}@students.ecanteen.invalid`; }
function requireStudent(request) {
  if (!request.auth || request.auth.token.role !== 'student') throw new HttpsError('unauthenticated', 'Please sign in as a student.');
  return request.auth.uid;
}
async function requireStaff(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in first.');
  const snap = await db.collection('canteen_staff').doc(request.auth.uid).get();
  if (!snap.exists || snap.data().active !== true) throw new HttpsError('permission-denied', 'Canteen staff access required.');
  return request.auth.uid;
}

// A registration number must be pre-approved by canteen/admin in student_registry.
// Document ID is the normalized registration number; never store passwords here.
exports.registerStudent = onCall(async (request) => {
  const regNo = normalizeRegistrationNumber(request.data?.registrationNumber);
  const password = request.data?.password;
  if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
    throw new HttpsError('invalid-argument', 'Password must be at least 8 characters.');
  }
  const registryRef = db.collection('student_registry').doc(regNo);
  let reservation;
  try {
    // Atomically reserve the approved record to prevent two registrations racing.
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(registryRef);
      if (!snap.exists || snap.data().active !== true) throw new HttpsError('permission-denied', 'This registration number has not been approved.');
      if (snap.data().claimedBy || snap.data().registrationPending === true) throw new HttpsError('already-exists', 'This registration number is already registered or being registered.');
      const data = snap.data();
      if (!String(data.name || '').trim()) throw new HttpsError('failed-precondition', 'The approved student record is missing a name.');
      reservation = {name: String(data.name).trim(), branch: String(data.branch || '').trim()};
      tx.update(registryRef, {registrationPending: true, registrationPendingAt: FieldValue.serverTimestamp()});
    });
  } catch (e) { throw e instanceof HttpsError ? e : new HttpsError('internal', 'Could not reserve this student record.'); }

  let user;
  try {
    user = await auth.createUser({email: studentEmail(regNo), password, displayName: reservation.name, emailVerified: true});
    await auth.setCustomUserClaims(user.uid, {role: 'student', registrationNumber: regNo});
    const customToken = await auth.createCustomToken(user.uid, {role: 'student', registrationNumber: regNo});
    const batch = db.batch();
    batch.set(db.collection('student_profiles').doc(user.uid), {
      registrationNumber: regNo, name: reservation.name, branch: reservation.branch,
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.update(registryRef, {
      claimedBy: user.uid, claimedAt: FieldValue.serverTimestamp(),
      registrationPending: FieldValue.delete(), registrationPendingAt: FieldValue.delete(),
    });
    await batch.commit();
    return {customToken};
  } catch (e) {
    // Only release the reservation if it wasn't successfully claimed by this account.
    if (user) await auth.deleteUser(user.uid).catch(() => {});
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(registryRef);
      if (snap.exists && !snap.data().claimedBy) tx.update(registryRef, {registrationPending: FieldValue.delete(), registrationPendingAt: FieldValue.delete()});
    }).catch(() => {});
    if (e instanceof HttpsError) throw e;
    if (e.code === 'auth/email-already-exists') throw new HttpsError('already-exists', 'An account already exists for this registration number.');
    throw new HttpsError('internal', 'Could not finish student registration. Please try again.');
  }
});

exports.createOrder = onCall(async (request) => {
  const uid = requireStudent(request);
  const profileSnap = await db.collection('student_profiles').doc(uid).get();
  if (!profileSnap.exists) throw new HttpsError('failed-precondition', 'Student profile not found. Sign in again.');
  const profile = profileSnap.data();
  const requestedItems = request.data?.items;
  const pickupTime = String(request.data?.pickupTime || '').trim();
  const paymentMethod = request.data?.paymentMethod;
  const note = String(request.data?.note || '').trim().slice(0, 300);
  if (!Array.isArray(requestedItems) || requestedItems.length < 1 || requestedItems.length > 30) throw new HttpsError('invalid-argument', 'Your cart is empty or invalid.');
  if (!pickupTime || pickupTime.length > 100) throw new HttpsError('invalid-argument', 'Choose a pickup time.');
  if (!['Cash', 'UPI'].includes(paymentMethod)) throw new HttpsError('invalid-argument', 'Invalid payment method.');

  const items = []; let total = 0; const seen = new Set();
  for (const requested of requestedItems) {
    const foodId = String(requested?.foodId || '').trim();
    const quantity = Number(requested?.quantity);
    if (!foodId || seen.has(foodId) || !Number.isInteger(quantity) || quantity < 1 || quantity > 50) throw new HttpsError('invalid-argument', 'An item or quantity is invalid.');
    seen.add(foodId);
    const menuSnap = await db.collection('menu_items').doc(foodId).get();
    if (!menuSnap.exists) throw new HttpsError('failed-precondition', 'A menu item no longer exists.');
    const menu = menuSnap.data();
    if (menu.active === false || menu.available === false || menu.isAvailable === false) throw new HttpsError('failed-precondition', `${menu.name || 'An item'} is unavailable.`);
    const price = Number(menu.price);
    if (!Number.isFinite(price) || price < 0) throw new HttpsError('failed-precondition', 'A menu item has an invalid price.');
    items.push({foodId, name: String(menu.name || 'Menu item'), price, quantity, emoji: String(menu.emoji || '🍽️')});
    total += price * quantity;
  }
  const now = Timestamp.now();
  const ref = db.collection('orders').doc();
  await ref.create({
    studentUid: uid, studentName: String(profile.name || ''), studentId: String(profile.registrationNumber || ''),
    branch: String(profile.branch || ''), items, total,
    pickupTime, pickupAt: null, paymentMethod: paymentMethod === 'UPI' ? 'UPI (pending)' : 'Cash',
    status: 'newOrder', createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(now.toMillis() + 90 * 24 * 60 * 60 * 1000), note, estimatedPrepMinutes: 10,
  });
  return {orderId: ref.id};
});

exports.cancelOrder = onCall(async (request) => {
  const uid = requireStudent(request);
  const orderId = String(request.data?.orderId || '').trim();
  if (!orderId) throw new HttpsError('invalid-argument', 'Order ID is required.');
  const ref = db.collection('orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.data().studentUid !== uid) throw new HttpsError('not-found', 'Order not found.');
    if (snap.data().status !== 'newOrder') throw new HttpsError('failed-precondition', 'This order can no longer be cancelled because the canteen has accepted it.');
    tx.update(ref, {status: 'cancelled', updatedAt: FieldValue.serverTimestamp()});
  });
  return {success: true};
});

exports.updateOrderStatus = onCall(async (request) => {
  await requireStaff(request);
  const orderId = String(request.data?.orderId || '').trim();
  const nextStatus = String(request.data?.status || '').trim();
  if (!orderId) throw new HttpsError('invalid-argument', 'Order ID is required.');
  const transitions = {newOrder: ['confirmed'], confirmed: ['preparing'], accepted: ['preparing'], preparing: ['ready'], ready: ['collected']};
  const ref = db.collection('orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
    const current = String(snap.data().status || 'newOrder');
    if (!(transitions[current] || []).includes(nextStatus)) throw new HttpsError('failed-precondition', `Cannot change an order from ${current} to ${nextStatus}.`);
    tx.update(ref, {status: nextStatus, updatedAt: FieldValue.serverTimestamp()});
  });
  return {success: true};
});
