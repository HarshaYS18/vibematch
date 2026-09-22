import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/watch_party/providers/youtube/youtube_content_id.dart';

void main() {
  test('normalizes supported YouTube identifiers and URLs', () {
    expect(YouTubeContentId.tryParse('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    expect(
      YouTubeContentId.tryParse(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=3s',
      ),
      'dQw4w9WgXcQ',
    );
    expect(
      YouTubeContentId.tryParse('https://youtu.be/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      YouTubeContentId.tryParse(
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
      ),
      'dQw4w9WgXcQ',
    );
    expect(
      YouTubeContentId.tryParse(
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
      ),
      'dQw4w9WgXcQ',
    );
  });

  test('rejects non-YouTube and malformed content', () {
    expect(YouTubeContentId.tryParse('https://example.com/dQw4w9WgXcQ'), isNull);
    expect(YouTubeContentId.tryParse('too-short'), isNull);
    expect(YouTubeContentId.tryParse(null), isNull);
  });
}
