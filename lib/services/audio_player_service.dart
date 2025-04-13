import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:math';
import '../models/radio_station.dart';
import 'package:audio_service/audio_service.dart';

// Position data to track playback state
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioPlayerService {
  // Singleton instance
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  // Audio player
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  AudioHandler? _audioHandler;

  // Current station
  RadioStation? _currentStation;

  // Public getters
  AudioPlayer get audioPlayer => _audioPlayer;
  RadioStation? get currentStation => _currentStation;
  Stream<bool> get playingStream => _audioPlayer.playingStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  bool get playing => _isInitialized ? _audioPlayer.playing : false;

  // Combined stream for current position, buffered position and duration
  Stream<PositionData>? _positionDataStream;
  Stream<PositionData> get positionDataStream {
    if (!_isInitialized) {
      return Stream.value(
          PositionData(Duration.zero, Duration.zero, Duration.zero));
    }

    _positionDataStream ??=
        Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
      _audioPlayer.positionStream,
      _audioPlayer.bufferedPositionStream,
      _audioPlayer.durationStream,
      (position, bufferedPosition, duration) =>
          PositionData(position, bufferedPosition, duration ?? Duration.zero),
    );

    return _positionDataStream!;
  }

  // Initialize audio session
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _audioPlayer = AudioPlayer();

      // Set up audio session
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Handle interruptions
      _handleInterruptions(session);

      // Log errors to console
      _audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace st) {
          if (e is PlayerException) {
            print('Error code: ${e.code}');
            print('Error message: ${e.message}');
          } else {
            print('An error occurred: $e');
          }
        },
      );

      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize audio player: $e');
      // Create a player anyway to avoid null errors
      _audioPlayer = AudioPlayer();
    }
  }

  // Load and play a radio station
  Future<void> playStation(RadioStation station) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      _currentStation = station;

      // Reset the player
      await _audioPlayer.stop();

      print('Attempting to play radio stream: ${station.streamUrl}');

      // Set URL with a reasonable timeout
      await _audioPlayer.setUrl(
        station.streamUrl,
        preload: true,
      );

      // Add small delay to allow buffering
      await Future.delayed(const Duration(milliseconds: 500));

      // Start playing
      await _audioPlayer.play();
      print('Started playing ${station.name}');
    } catch (e) {
      print('Error playing station: $e');

      // Try with a fallback URL pattern if the original failed
      if (_currentStation != null) {
        try {
          final String stationId = station.id.split('_').last;
          final String fallbackUrl =
              'https://stream.radio.co/${stationId}/listen';

          print('Trying fallback URL: $fallbackUrl');
          await _audioPlayer.setUrl(fallbackUrl);
          await _audioPlayer.play();
          print('Playing with fallback URL');
        } catch (fallbackError) {
          print('Fallback also failed: $fallbackError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  // Toggle play/pause
  Future<void> togglePlayPause() async {
    if (!_isInitialized) return;

    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  // Stop playing
  Future<void> stop() async {
    if (!_isInitialized) return;

    await _audioPlayer.stop();
    _currentStation = null;
  }

  // Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;

    volume = max(0.0, min(1.0, volume));
    await _audioPlayer.setVolume(volume);
  }

  // Handle audio interruptions
  void _handleInterruptions(AudioSession session) {
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        // Audio session was interrupted
        if (event.type == AudioInterruptionType.duck) {
          // Lower volume for ducking
          _audioPlayer.setVolume(0.3);
        } else {
          // Pause for other interruptions
          _audioPlayer.pause();
        }
      } else {
        // Interruption ended
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Restore volume
            _audioPlayer.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // Resume if we were playing before
            if (!_audioPlayer.playing) {
              _audioPlayer.play();
            }
            break;
        }
      }
    });
  }

  // Dispose of resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _audioPlayer.dispose();
      _isInitialized = false;
    }
  }
}

// AudioHandler implementation for audio_service
class AudioHandlerImpl extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  final _mediaItem = BehaviorSubject<MediaItem>.seeded(const MediaItem(
    id: 'no_id',
    title: 'No Title',
  ));

  AudioHandlerImpl() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.playerStateStream.listen((playerState) {
      _broadcastState(_player.playbackEvent);
    });
  }

  Future<void> updateMediaItem(MediaItem item) async {
    _mediaItem.add(item);
    mediaItem.add(item);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[_player.processingState]!;

    // Create a new playback state
    final newState = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );

    // Update the playback state
    playbackState.add(newState);
  }
}
