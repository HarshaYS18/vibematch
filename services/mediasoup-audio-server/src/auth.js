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

  const claims = jwt.verify(audioToken, config.auth.jwtSecret, {
    algorithms: [config.auth.jwtAlgorithm],
  });

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
