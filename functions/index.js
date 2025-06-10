const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const express = require('express');
const cors = require('cors');

admin.initializeApp();
const db = admin.firestore();
const app = express();

setGlobalOptions({ region: "asia-northeast3" });
app.use(cors({ origin: true }));
app.use(express.json());

/**
 * 🔹 기존 기능: 24시간마다 미인증 사용자 삭제
 * Firebase 사용자 등록 또는 기존 사용자 확인
 */
exports.deleteUnverifiedUsers = onSchedule("every 24 hours", async (event) => {
  const firestore = admin.firestore();
  const now = new Date();
  const cutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000);
const createOrGetUser = async (uid, email, provider) => {
  try {
    // 사용자 있는지 확인
    await admin.auth().getUser(uid);
  } catch (error) {
    // 없으면 생성
    await admin.auth().createUser({
      uid,
      email,
      displayName: `${provider} User`,
    });
  }

  const usersRef = firestore.collection("tempUsers");
  const snapshot = await usersRef.where("status", "==", "pending").get();
  // Firestore에 사용자 정보 저장
  const userRef = db.collection("users").doc(uid);
  await userRef.set(
    {
      email,
      provider,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
};

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const createdAt = data.createdAt ? data.createdAt.toDate() : null;
// 네이버 로그인 처리
app.post("/naver", async (req, res) => {
  const naverAuthCode = req.body.naverAuthCode;
  console.log("Received Naver auth code:", naverAuthCode);

  if (!naverAuthCode) {
    console.log("Error: Missing Naver auth code");
    return res.status(400).send({ error: "Missing Naver auth code" });
  }

    if (createdAt && createdAt < cutoff) {
      try {
        await admin.auth().deleteUser(doc.id);
        await doc.ref.delete();
        console.log(`Deleted unverified user: ${doc.id}`);
      } catch (error) {
        console.error(`Error deleting user ${doc.id}:`, error);
      }
  try {
    // 네이버 API로 인증 코드로 토큰 요청
    console.log("Requesting token from Naver API...");
    const tokenResponse = await axios.post('https://nid.naver.com/oauth2.0/token', null, {
      params: {
        client_id: 'PLHdaznm0rzZR_ejyPhp',  // 네이버 개발자 센터에서 발급받은 Client ID
        client_secret: 'O5s1TxHiiE',  // 네이버 개발자 센터에서 발급받은 Client Secret
        code: naverAuthCode,
        grant_type: 'authorization_code',
        redirect_uri: 'https://authcustomtoken-lczljd5ldq-uc.a.run.app',  // Firebase Functions URL
      },
    });

    const accessToken = tokenResponse.data.access_token;

    // 네이버 사용자 정보 조회
    const userResponse = await axios.get('https://openapi.naver.com/v1/nid/me', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    console.log("User info retrieved from Naver:", userResponse.data);

    const user = userResponse.data.response;
    const naverUid = user.id;
    const naverEmail = user.email || `${naverUid}@naver.com`;

    // Firebase 사용자 등록 또는 업데이트
    await createOrGetUser(naverUid, naverEmail, "NAVER");

    // Firebase Custom Token 생성
    const customToken = await admin.auth().createCustomToken(naverUid, {
      provider: 'NAVER',
      email: naverEmail,
    });

    // 앱으로 리디렉션 URL 반환 (Firebase Functions에서 앱으로 리디렉션)
    console.log("Firebase custom token created:", customToken);

    // 이 부분에서 Custom Token을 앱으로 전달
    // Firebase Custom Token을 응답으로 반환
    res.status(200).send({ token: customToken });

  } catch (error) {
    console.error('Naver login error:', error.message);
    if (error.response) {
      console.error('Error details:', error.response.data);
    }
    res.status(500).send({ error: 'Failed to authenticate with Naver' });
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

// Firebase Functions export
exports.authCustomToken = functions.https.onRequest(app);
