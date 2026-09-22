import '../../../foundation/telemetry/app_telemetry.dart';
import '../companion/companion_playback_adapter.dart';
import '../web/ott_provider_definition.dart';
import '../web/ott_web_playback_host.dart';
import '../web/supported_web_playback_adapter.dart';

class JioHotstarProviderAdapter extends SupportedWebPlaybackAdapter {
  JioHotstarProviderAdapter({
    OttWebPlaybackHost? host,
    CompanionPlaybackAdapter? companion,
    super.telemetry = const AppTelemetry(),
  }) : super(
         provider: OttProviderCatalog.jioHotstar,
         host:
             host ??
             InAppWebViewOttPlaybackHost(
               provider: OttProviderCatalog.jioHotstar,
             ),
         companion:
             companion ??
             CompanionPlaybackAdapter(provider: OttProviderCatalog.jioHotstar),
         telemetry: telemetry,
       );
}
