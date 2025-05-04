const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const express = require("express");
const cors = require("cors");

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

/**
 * ✅ Kakao 로그인 처리
 */
app.post("/kakao", async (req, res) => {
  const kakaoAccessToken = req.body.kakaoAccessToken;

  if (!kakaoAccessToken) {
    return res.status(400).send({ error: "Missing Kakao access token" });
  }

  try {
    const kakaoResponse = await axios.get("https://kapi.kakao.com/v2/user/me", {
      headers: {
        Authorization: `Bearer ${kakaoAccessToken}`,
      },
    });

    const kakaoData = kakaoResponse.data;
    const kakaoUid = kakaoData.id.toString();
    const kakaoEmail = kakaoData.kakao_account?.email || `${kakaoUid}@kakao.com`;

    await createOrGetUser(kakaoUid, kakaoEmail, "KAKAO");

    const customToken = await admin.auth().createCustomToken(kakaoUid, {
      provider: "KAKAO",
      email: kakaoEmail,
    });

    res.status(200).send({ token: customToken });
  } catch (error) {
    console.error("Kakao login error:", error.response?.data || error.message);
    res.status(500).send({ error: "Failed to authenticate with Kakao" });
  }
});

/**
 * ✅ Naver 로그인 처리
 */
app.post("/naver", async (req, res) => {
  const naverAccessToken = req.body.naverAccessToken;

  if (!naverAccessToken) {
    return res.status(400).send({ error: "Missing Naver access token" });
  }

  try {
    const naverResponse = await axios.get("https://openapi.naver.com/v1/nid/me", {
      headers: {
        Authorization: `Bearer ${naverAccessToken}`,
      },
    });

    const naverData = naverResponse.data.response;
    const naverUid = naverData.id;
    const naverEmail = naverData.email || `${naverUid}@naver.com`;

    await createOrGetUser(naverUid, naverEmail, "NAVER");

    const customToken = await admin.auth().createCustomToken(naverUid, {
      provider: "NAVER",
      email: naverEmail,
    });

    res.status(200).send({ token: customToken });
  } catch (error) {
    console.error("Naver login error:", error.response?.data || error.message);
    res.status(500).send({ error: "Failed to authenticate with Naver" });
  }
});

exports.authCustomToken = functions.https.onRequest(app);
