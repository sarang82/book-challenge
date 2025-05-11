'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const express = require('express');
const cors = require('cors');

admin.initializeApp();
const db = admin.firestore();
const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

/**
 * Firebase 사용자 등록 또는 기존 사용자 확인
 */
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

// 네이버 로그인 처리
app.post("/naver", async (req, res) => {
  const naverAuthCode = req.body.naverAuthCode;
  console.log("Received Naver auth code:", naverAuthCode);

  if (!naverAuthCode) {
    console.log("Error: Missing Naver auth code");
    return res.status(400).send({ error: "Missing Naver auth code" });
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
});

// Firebase Functions export
exports.authCustomToken = functions.https.onRequest(app);
