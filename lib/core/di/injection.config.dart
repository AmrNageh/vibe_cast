// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:vibe_cast/features/walkie_talkie/bloc/walkie_talkie_bloc.dart'
    as _i217;
import 'package:vibe_cast/features/walkie_talkie/services/audio_capture_service.dart'
    as _i513;
import 'package:vibe_cast/features/walkie_talkie/services/audio_playback_service.dart'
    as _i199;
import 'package:vibe_cast/features/walkie_talkie/services/udp_transport_service.dart'
    as _i705;
import 'package:vibe_cast/features/walkie_talkie/services/walkie_repository.dart'
    as _i515;
import 'package:vibe_cast/features/walkie_talkie/services/walkie_signal_service.dart'
    as _i519;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i513.AudioCaptureService>(
      () => _i513.AudioCaptureService(),
    );
    gh.lazySingleton<_i199.AudioPlaybackService>(
      () => _i199.AudioPlaybackService(),
    );
    gh.lazySingleton<_i705.UdpTransportService>(
      () => _i705.UdpTransportService(),
    );
    gh.lazySingleton<_i515.WalkieRepository>(() => _i515.WalkieRepository());
    gh.lazySingleton<_i519.WalkieSignalService>(
      () => _i519.WalkieSignalService(),
    );
    gh.lazySingleton<_i217.WalkieTalkieBloc>(
      () => _i217.WalkieTalkieBloc(
        gh<_i513.AudioCaptureService>(),
        gh<_i199.AudioPlaybackService>(),
        gh<_i705.UdpTransportService>(),
        gh<_i519.WalkieSignalService>(),
        gh<_i515.WalkieRepository>(),
      ),
    );
    return this;
  }
}
