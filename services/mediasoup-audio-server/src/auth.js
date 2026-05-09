const jwt = require('jsonwebtoken');
const config = require('./config');

function validateAudioToken({ audioToken, roomId, peerId }) {
  if (!config.auth.requireAudioToken) {
    return {
      ok: true,
      claims: {
        room_id: roomId,
        peer_id: peerId,
        type: 'audio_session_dev_bypass',
      },
    };
  }

  if (!audioToken || typeof audioToken !== 'string') {
    throw new Error('audio token is required');
  }

  let claims;
  try {
    claims = jwt.verify(audioToken, config.auth.jwtSecret, {
      algorithms: [config.auth.jwtAlgorithm],
    });
  } catch (error) {
    const reason = error && error.message ? error.message : 'unknown token verification error';
    throw new Error(
      `audio token verification failed: ${reason}. ` +
        `Check AUDIO_JWT_SECRET_KEY/JWT_SECRET_KEY and AUDIO_JWT_ALGORITHM/JWT_ALGORITHM. ` +
        `mediasoup_secret_fingerprint=${config.auth.secretFingerprint}`,
    );
  }

  if (claims.type !== 'audio_session') {
    throw new Error('invalid audio token type');
  }

  if (claims.engine !== 'mediasoup') {
    throw new Error('invalid audio engine');
  }

  if (String(claims.room_id) !== String(roomId)) {
    throw new Error('audio token room mismatch');
  }

  if (String(claims.peer_id) !== String(peerId)) {
    throw new Error('audio token peer mismatch');
  }

  return {
    ok: true,
    claims,
  };
}

module.exports = {
  validateAudioToken,
};
