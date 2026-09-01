const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

admin.initializeApp();

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const COLLECTIONS = {
  appointments: 'appointments',
  postponedOffers: 'postponed_offers',
  notifications: 'notifications',
  users: 'users',
  adminActivityLogs: 'admin_activity_logs',
};

function toStringMap(data) {
  return Object.entries(data || {}).reduce((accumulator, [key, value]) => {
    if (value == null) return accumulator;
    if (typeof value === 'string') {
      accumulator[key] = value;
    } else if (typeof value === 'object') {
      accumulator[key] = JSON.stringify(value);
    } else {
      accumulator[key] = String(value);
    }
    return accumulator;
  }, {});
}

const STATUS = {
  pending: 'pending',
  approved: 'approved',
  cancelled: 'cancelled',
  rejected: 'rejected',
  postponed: 'postponed',
};

function asDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  return new Date(value);
}

function createNotificationTx(tx, { recipientId, recipientRole, title, body, type, data }) {
  const ref = db.collection(COLLECTIONS.notifications).doc();
  tx.set(ref, {
    recipientId,
    recipientRole,
    title,
    body,
    type,
    data: data || {},
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function createAdminLogTx(tx, { action, targetType, targetId, summary, metadata }) {
  const ref = db.collection(COLLECTIONS.adminActivityLogs).doc();
  tx.set(ref, {
    actorId: metadata?.actorId || 'system',
    actorRole: metadata?.actorRole || 'system',
    action,
    targetType,
    targetId,
    summary,
    metadata: metadata || {},
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function verifyPatientContext(uid) {
  const userSnap = await db.collection(COLLECTIONS.users).doc(uid).get();
  const userData = userSnap.exists ? (userSnap.data() || {}) : {};
  const role = (userData.role || '').toString();
  if (role && role !== 'patient') {
    throw new HttpsError('permission-denied', 'Only patients can process postponed offers.');
  }
  return userData;
}

exports.processPostponedOffer = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'You must be signed in to process this offer.');
  }

  const offerId = (request.data?.offerId || '').toString().trim();
  const action = (request.data?.action || '').toString().trim();

  if (!offerId) {
    throw new HttpsError('invalid-argument', 'offerId is required.');
  }

  if (action !== 'accept' && action !== 'decline') {
    throw new HttpsError('invalid-argument', 'action must be accept or decline.');
  }

  const uid = request.auth.uid;
  await verifyPatientContext(uid);

  const offerRef = db.collection(COLLECTIONS.postponedOffers).doc(offerId);

  const result = await db.runTransaction(async (tx) => {
    const offerSnap = await tx.get(offerRef);
    if (!offerSnap.exists) {
      throw new HttpsError('not-found', 'Postponed offer not found.');
    }

    const offer = offerSnap.data() || {};
    const offerStatus = (offer.status || 'pending').toString();
    const patientId = (offer.patientId || '').toString();
    const doctorId = (offer.doctorId || '').toString();
    const appointmentId = (offer.appointmentId || '').toString();
    const originalSlot = (offer.originalSlot || '').toString();

    if (!patientId || !doctorId || !appointmentId) {
      throw new HttpsError('failed-precondition', 'Offer is incomplete.');
    }

    if (patientId !== uid) {
      throw new HttpsError('permission-denied', 'This offer does not belong to your account.');
    }

    if (offerStatus !== STATUS.pending) {
      throw new HttpsError('failed-precondition', 'This offer has already been handled.');
    }

    const expiresAt = asDate(offer.expiresAt);
    if (expiresAt && expiresAt.getTime() < Date.now()) {
      tx.update(offerRef, {
        status: 'expired',
        resolvedAt: FieldValue.serverTimestamp(),
      });
      createNotificationTx(tx, {
        recipientId: patientId,
        recipientRole: 'patient',
        title: 'Postponed offer expired',
        body: 'Your postponed appointment offer expired before you responded.',
        type: 'postpone_offer_expired',
        data: { offerId, appointmentId, doctorId },
      });
      createNotificationTx(tx, {
        recipientId: doctorId,
        recipientRole: 'doctor',
        title: 'Postponed offer expired',
        body: 'A postponed appointment offer expired without a response.',
        type: 'postpone_offer_expired',
        data: { offerId, appointmentId, patientId },
      });
      createAdminLogTx(tx, {
        action: 'postponement_expired',
        targetType: COLLECTIONS.appointments,
        targetId: appointmentId,
        summary: 'A postponed appointment offer expired.',
        metadata: { offerId, appointmentId, patientId, doctorId, actorId: 'system', actorRole: 'system' },
      });
      return { message: 'This offer has expired.' };
    }

    const appointmentRef = db.collection(COLLECTIONS.appointments).doc(appointmentId);
    const appointmentSnap = await tx.get(appointmentRef);
    if (!appointmentSnap.exists) {
      throw new HttpsError('not-found', 'Appointment not found.');
    }

    const appointment = appointmentSnap.data() || {};
    const appointmentStatus = (appointment.status || '').toString();

    if (appointmentStatus !== STATUS.postponed) {
      throw new HttpsError('failed-precondition', 'This appointment is no longer postponed.');
    }

    if (action === 'decline') {
      tx.update(offerRef, {
        status: 'declined',
        resolvedAt: FieldValue.serverTimestamp(),
      });
      tx.update(appointmentRef, {
        status: STATUS.cancelled,
        cancelledAt: FieldValue.serverTimestamp(),
        cancelledBy: uid,
        cancelReason: 'Patient declined postponed offer',
      });

      createNotificationTx(tx, {
        recipientId: doctorId,
        recipientRole: 'doctor',
        title: 'Postponed offer declined',
        body: 'A patient declined the postponed appointment offer.',
        type: 'postpone_offer_declined',
        data: { offerId, appointmentId, patientId, doctorId, slot: originalSlot },
      });
      createNotificationTx(tx, {
        recipientId: patientId,
        recipientRole: 'patient',
        title: 'Appointment cancelled',
        body: 'Your postponed appointment has been cancelled.',
        type: 'appointment_cancelled',
        data: { offerId, appointmentId, doctorId },
      });
      createAdminLogTx(tx, {
        action: 'postponement_declined',
        targetType: COLLECTIONS.appointments,
        targetId: appointmentId,
        summary: 'Patient declined a postponed appointment offer.',
        metadata: { offerId, appointmentId, patientId, doctorId, actorId: uid, actorRole: 'patient' },
      });

      return { message: 'Postponed offer declined.' };
    }

    const appointmentDate = asDate(offer.originalDate) || asDate(appointment.appointmentDate);
    if (!appointmentDate) {
      throw new HttpsError('failed-precondition', 'Unable to resolve the appointment date.');
    }

    const nextDay = new Date(appointmentDate);
    nextDay.setDate(nextDay.getDate() + 1);

    const startOfDay = new Date(nextDay);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(nextDay);
    endOfDay.setHours(23, 59, 59, 999);

    const conflictQuery = db
      .collection(COLLECTIONS.appointments)
      .where('doctorId', '==', doctorId)
      .where('appointmentDate', '>=', Timestamp.fromDate(startOfDay))
      .where('appointmentDate', '<=', Timestamp.fromDate(endOfDay));

    const conflictSnap = await tx.get(conflictQuery);
    const hasConflict = conflictSnap.docs.some((doc) => {
      if (doc.id === appointmentId) return false;
      const data = doc.data() || {};
      const slot = (data.slot || '').toString();
      const status = (data.status || '').toString();
      return slot === originalSlot &&
        status !== STATUS.cancelled &&
        status !== STATUS.rejected &&
        status !== STATUS.postponed;
    });

    if (hasConflict) {
      throw new HttpsError('failed-precondition', 'That slot is no longer available for the next day.');
    }

    tx.update(appointmentRef, {
      appointmentDate: Timestamp.fromDate(nextDay),
      status: STATUS.approved,
      postponedResolvedAt: FieldValue.serverTimestamp(),
      postponedOfferId: offerId,
    });
    tx.update(offerRef, {
      status: 'accepted',
      resolvedAt: FieldValue.serverTimestamp(),
    });

    createNotificationTx(tx, {
      recipientId: doctorId,
      recipientRole: 'doctor',
      title: 'Postponed appointment accepted',
      body: 'A patient accepted the same-slot next-day reschedule.',
      type: 'postpone_offer_accepted',
      data: { offerId, appointmentId, patientId, doctorId, slot: originalSlot },
    });
    createNotificationTx(tx, {
      recipientId: patientId,
      recipientRole: 'patient',
      title: 'Appointment rescheduled',
      body: 'Your postponed appointment has been moved to the next day.',
      type: 'appointment_rescheduled',
      data: { offerId, appointmentId, doctorId, slot: originalSlot },
    });
    createAdminLogTx(tx, {
      action: 'postponement_accepted',
      targetType: COLLECTIONS.appointments,
      targetId: appointmentId,
      summary: 'Patient accepted a postponed appointment offer.',
      metadata: { offerId, appointmentId, patientId, doctorId, actorId: uid, actorRole: 'patient' },
    });

    return { message: 'Appointment moved to the next day.' };
  });

  return result;
});

exports.expirePostponedOffers = onSchedule('every 5 minutes', async () => {
  const now = Timestamp.now();
  const snapshot = await db
    .collection(COLLECTIONS.postponedOffers)
    .where('status', '==', STATUS.pending)
    .where('expiresAt', '<=', now)
    .get();

  for (const doc of snapshot.docs) {
    await db.runTransaction(async (tx) => {
      const offerRef = doc.ref;
      const freshOffer = await tx.get(offerRef);
      if (!freshOffer.exists) return;

      const offer = freshOffer.data() || {};
      if ((offer.status || '').toString() !== STATUS.pending) return;

      const appointmentId = (offer.appointmentId || '').toString();
      const patientId = (offer.patientId || '').toString();
      const doctorId = (offer.doctorId || '').toString();
      const appointmentRef = db.collection(COLLECTIONS.appointments).doc(appointmentId);
      const appointmentSnap = await tx.get(appointmentRef);

      tx.update(offerRef, {
        status: 'expired',
        resolvedAt: FieldValue.serverTimestamp(),
      });

      if (appointmentSnap.exists) {
        const appointment = appointmentSnap.data() || {};
        if ((appointment.status || '').toString() === STATUS.postponed) {
          tx.update(appointmentRef, {
            status: STATUS.cancelled,
            cancelledAt: FieldValue.serverTimestamp(),
            cancelledBy: 'system',
            cancelReason: 'Postponed offer expired',
          });
        }
      }

      createNotificationTx(tx, {
        recipientId: patientId,
        recipientRole: 'patient',
        title: 'Postponed offer expired',
        body: 'Your postponed appointment offer expired before you responded.',
        type: 'postpone_offer_expired',
        data: { offerId: doc.id, appointmentId, doctorId },
      });
      createNotificationTx(tx, {
        recipientId: doctorId,
        recipientRole: 'doctor',
        title: 'Postponed offer expired',
        body: 'A postponed appointment offer expired without a response.',
        type: 'postpone_offer_expired',
        data: { offerId: doc.id, appointmentId, patientId },
      });
      createAdminLogTx(tx, {
        action: 'postponement_expired',
        targetType: COLLECTIONS.appointments,
        targetId: appointmentId,
        summary: 'A postponed appointment offer expired.',
        metadata: { offerId: doc.id, appointmentId, patientId, doctorId, actorId: 'system', actorRole: 'system' },
      });
    });
  }
});

exports.sendNotificationPush = onDocumentCreated(
  `${COLLECTIONS.notifications}/{notificationId}`,
  async (event) => {
    const notification = event.data?.data();
    if (!notification) return;

    const recipientId = (notification.recipientId || '').toString().trim();
    const title = (notification.title || 'AidLink').toString();
    const body = (notification.body || '').toString();
    const type = (notification.type || '').toString();
    const rawData = notification.data && typeof notification.data === 'object'
      ? notification.data
      : {};

    if (!recipientId) return;

    const userSnap = await db.collection(COLLECTIONS.users).doc(recipientId).get();
    if (!userSnap.exists) return;

    const userData = userSnap.data() || {};
    const token = (userData.fcmToken || '').toString().trim();
    if (!token) return;

    const message = {
      token,
      notification: { title, body },
      data: toStringMap({
        ...rawData,
        title,
        body,
        type,
        recipientId,
      }),
      android: {
        priority: 'high',
      },
    };

    try {
      await admin.messaging().send(message);
    } catch (error) {
      const code = (error && error.code) || '';
      if (code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token') {
        await db.collection(COLLECTIONS.users).doc(recipientId).set(
          { fcmToken: FieldValue.delete() },
          { merge: true },
        );
      }
      throw error;
    }
  }
);
