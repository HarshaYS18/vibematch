import 'package:flutter_test/flutter_test.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  test('vendored SDP parser preserves unknown attributes', () {
    final session = parse(
      'v=0\r\n'
      'o=- 0 0 IN IP4 127.0.0.1\r\n'
      's=-\r\n'
      't=0 0\r\n'
      'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
      'a=x-funkey-unknown:1\r\n',
    );

    final media = session['media'] as List<dynamic>;
    expect(media, hasLength(1));

    final invalid = (media.first as Map<dynamic, dynamic>)['invalid']
        as List<dynamic>;
    expect(
      invalid.any(
        (entry) =>
            entry is Map<dynamic, dynamic> &&
            entry['value'] == 'x-funkey-unknown:1',
      ),
      isTrue,
    );
  });
}
