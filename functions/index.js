const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({ region: "asia-northeast3" });

/**
 * 🔹 기존 기능: 24시간마다 미인증 사용자 삭제
 */
exports.deleteUnverifiedUsers = onSchedule("every 24 hours", async (event) => {
  const firestore = admin.firestore();
  const now = new Date();
  const cutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000);

  const usersRef = firestore.collection("tempUsers");
  const snapshot = await usersRef.where("status", "==", "pending").get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const createdAt = data.createdAt ? data.createdAt.toDate() : null;

    if (createdAt && createdAt < cutoff) {
      try {
        await admin.auth().deleteUser(doc.id);
        await doc.ref.delete();
        console.log(`Deleted unverified user: ${doc.id}`);
      } catch (error) {
        console.error(`Error deleting user ${doc.id}:`, error);
      }
    }
  }

  return null;
});

/**
 * 사용자 설정 알림 발송
 */
exports.sendRecurringNotifications = onSchedule("every 10 minutes", async (event) => {
  const now = new Date();
  const koreaNow = new Date(now.getTime() + 9 * 60 * 60 * 1000); // KST = UTC + 9

  const hour = koreaNow.getHours();
  const minute = koreaNow.getMinutes();
  const day = (koreaNow.getDay() + 6) % 7; // 월=0 ~ 일=6

  const snapshot = await admin.firestore().collection("notification_schedule").get();

  const messages = [];

  snapshot.forEach(doc => {
    const data = doc.data();
    if (data.hour === hour && data.minute === minute && data.days?.[day]) {
      messages.push({
        token: data.token,
        notification: {
          title: "톡독 TalkDok!",
          body: "톡독과 함께 오늘도 독서를 시작해보세요!",
        },
      });
    }
  });

  if (messages.length > 0) {
    const results = await Promise.all(messages.map((m) => admin.messaging().send(m)));
    console.log(`${results.length}개의 알림 전송 완료`);
  } else {
    console.log("전송할 알림 없음");
  }

  return null;
});

