const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const express = require("express");

admin.initializeApp();
const app = express();

// JSON 파서 미들웨어 추가
app.use(express.json());

app.post("/", async (req, res) => {
  const kakaoAccessToken = req.body.kakaoAccessToken;

  if (!kakaoAccessToken) {
    return res.status(400).send({ error: "Missing Kakao access token" });
  }

  try {
    // Kakao 사용자 정보 조회
    const kakaoResponse = await axios.get("https://kapi.kakao.com/v2/user/me", {
      headers: {
        Authorization: `Bearer ${kakaoAccessToken}`,
      },
    });

    const kakaoUid = kakaoResponse.data.id.toString();
    const kakaoEmail = kakaoResponse.data.kakao_account?.email;

    const customToken = await admin.auth().createCustomToken(kakaoUid, {
      provider: "KAKAO",
      email: kakaoEmail,
    });

    res.status(200).send({ token: customToken });
  } catch (error) {
    console.error("Kakao login error:", error);
    res.status(500).send({ error: "Failed to authenticate with Kakao" });
  }
});

//export 형식 변경
exports.kakaoCustomAuth = functions.https.onRequest(app);
