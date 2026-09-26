import '../../../foundation/telemetry/app_telemetry.dart';
import '../companion/companion_playback_adapter.dart';
import '../web/ott_provider_definition.dart';
import '../web/ott_web_playback_host.dart';
import '../web/supported_web_playback_adapter.dart';

class NetflixProviderAdapter extends SupportedWebPlaybackAdapter {
  NetflixProviderAdapter({
    OttWebPlaybackHost? host,
    CompanionPlaybackAdapter? companion,
    super.telemetry = const AppTelemetry(),
    super.remountBarrier,
  }) : super(
         provider: OttProviderCatalog.netflix,
         host:
             host ??
             InAppWebViewOttPlaybackHost(
               provider: OttProviderCatalog.netflix,
             ),
         companion:
             companion ??
             CompanionPlaybackAdapter(provider: OttProviderCatalog.netflix),
       );
}
