import 'dart:async';
import 'dart:typed_data';

import 'package:stream_isolate/stream_isolate.dart';
import 'package:fast_noise/fast_noise.dart';

class ThreadParams {
  final int index;
  final int width;
  final int minY;
  final int maxY;
  final double scale;
  final double velocity;
  final int seed;

  const ThreadParams({
    required this.index,
    required this.width,
    required this.minY,
    required this.maxY,
    this.scale = 1,
    this.seed = 1337,
    this.velocity = 1000,
  });
}

class ThreadMessages {
  static const requestData = 'REQUEST_DATA';
  static const changeScale = 'CHANGE_SCALE';
  static const changeVelocity = 'CHANGE_VELOCITY';
  static const stop = 'STOP';
}

class ThreadMessage {
  final String message;
  final dynamic payload;

  const ThreadMessage(this.message, this.payload);

  const ThreadMessage.requestData(double t)
      : this(ThreadMessages.requestData, t);

  const ThreadMessage.changeScale(double newScale)
      : this(ThreadMessages.changeScale, newScale);

  const ThreadMessage.changeVelocity(double newVelocity)
      : this(ThreadMessages.changeVelocity, newVelocity);

  const ThreadMessage.stop() : this(ThreadMessages.stop, null);
}

class ThreadPackage {
  final int index;
  final Uint8List data;

  const ThreadPackage({
    required this.index,
    required this.data,
  });
}

class NoiseSimulation {
  final int width;
  final int height;
  final void Function(Uint8List data) onData;

  final _simulationTime = Stopwatch();
  final _frameTime = Stopwatch();

  late final List<double> _frameTimes;
  int _frameTimesIdx = 0;
  double get averageFrameTime {
    final populatedSamples = _frameTimes.where((x) => x >= 0);
    if (populatedSamples.isEmpty) return -1;
    return populatedSamples.reduce((a, b) => a + b) / populatedSamples.length;
  }

  bool _running = false;
  bool get running => _running;

  int _threads;
  set threads(int count) {
    if (running) {
      throw StateError(
          'Cannot change thread count while simulation is running.');
    }
    _threads = count;
  }

  double _scale;
  set scale(double scale) {
    _scale = scale;
    if (running) _sendChangeScaleMessage();
  }

  double _velocity;
  set velocity(double velocity) {
    _velocity = velocity;
    if (running) _sendChangeVelocityMessage();
  }

  int _seed;
  set seed(int val) {
    if (running) {
      throw StateError('Cannot change seed while simulation is running.');
    }
    _seed = val;
  }

  List<BidirectionalStreamIsolate<ThreadMessage, ThreadPackage, ThreadParams>?>
      _isolates;

  NoiseSimulation({
    required this.width,
    required this.height,
    required this.onData,
    double scale = 1,
    double velocity = 1000,
    int threads = 1,
    int seed = 1337,
    int frameTimeSamples = 20,
  })  : _threads = threads,
        _scale = scale,
        _velocity = velocity,
        _seed = seed,
        _isolates = [] {
    _frameTimes = List.filled(frameTimeSamples, -1);
  }

  Future<void> start() async {
    if (running) {
      throw StateError('Cannot start simulation: already running');
    }

    print('Starting simulation with $_threads threads...');

    _simulationTime.reset();
    _simulationTime.start();

    _isolates = List.filled(_threads, null);
    _running = true;

    final sectionHeight = height ~/ _threads;
    for (int i = 0; i < _threads; i++) {
      final minY = sectionHeight * i;
      final maxY = i + 1 == _threads ? height : minY + sectionHeight;

      final param = ThreadParams(
        index: i,
        width: width,
        minY: minY,
        maxY: maxY,
        seed: _seed,
        scale: _scale,
        velocity: _velocity,
      );

      final isolate = await BidirectionalStreamIsolate.spawnWithArgument(
        _generateNoise,
        argument: param,
      );

      isolate.stream.listen(_frameDataListener);

      _isolates[i] = isolate;
    }

    await Future.delayed(const Duration(milliseconds: 10));
    requestNextFrame();
  }

  void _sendChangeScaleMessage() {
    if (!running) return;

    final message = ThreadMessage.changeScale(_scale);
    for (final isolate in _isolates) {
      isolate?.send(message);
    }
  }

  void _sendChangeVelocityMessage() {
    if (!running) return;

    final message = ThreadMessage.changeVelocity(_velocity);
    for (final isolate in _isolates) {
      isolate?.send(message);
    }
  }

  void requestNextFrame() {
    if (!running) return;

    final t = _simulationTime.elapsed.inMicroseconds / 1000000;
    final message = ThreadMessage.requestData(t);

    _frameTime.reset();
    _frameTime.start();

    for (final isolate in _isolates) {
      isolate?.send(message);
    }
  }

  List<Uint8List?>? frameData;
  void _frameDataListener(ThreadPackage package) {
    frameData ??= List.filled(_threads, null);

    frameData![package.index] = package.data;

    if (frameData!.every((element) => element != null)) {
      _frameTime.stop();
      _insertFrameTime();

      final builder = BytesBuilder(copy: false);
      for (var element in frameData!) {
        builder.add(element!);
      }

      final fullFrame = builder.toBytes();
      onData(fullFrame);

      frameData = null;
    }
  }

  void _insertFrameTime() {
    _frameTimes[_frameTimesIdx] = _frameTime.elapsedMicroseconds / 1000;
    _frameTimesIdx = (_frameTimesIdx + 1) % _frameTimes.length;
  }

  Future<void> stop() async {
    if (!running) return;

    print('Stopping simulation...');

    final futures = List.generate(_isolates.length, (index) {
      final isolate = _isolates[index];
      isolate?.send(const ThreadMessage.stop());
      return isolate?.getIsClosedFuture() ?? Future.value();
    });

    await Future.wait(futures);
    _simulationTime.stop();
    _running = false;
  }
}

Stream<ThreadPackage> _generateNoise(
  Stream<ThreadMessage> messages,
  ThreadParams arg,
) async* {
  const bpp = 4;

  final noise = PerlinNoise(seed: arg.seed);

  final index = arg.index;
  final width = arg.width;
  final miny = arg.minY;
  final maxy = arg.maxY;

  double scale = arg.scale;
  double velocity = arg.velocity;

  final stride = (width * bpp);
  final height = (maxy - miny);
  final size = (stride * height);

  var coord = 0;
  var sample = 0.0;
  var value = 0;

  await for (var msg in messages) {
    if (msg.message == ThreadMessages.stop) break;

    if (msg.message == ThreadMessages.changeScale) {
      scale = msg.payload as double;
    }

    if (msg.message == ThreadMessages.changeVelocity) {
      velocity = msg.payload as double;
    }

    if (msg.message == ThreadMessages.requestData) {
      final data = Uint8List(size);
      final t = msg.payload as double;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          coord = (y * stride) + (x * bpp);
          sample = noise.getNoise3(x * scale, (y + miny) * scale, t * velocity);
          sample = (sample + 1) / 2;
          value = (sample * 255).toInt();
          data[coord] = value;
          data[coord + 1] = value;
          data[coord + 2] = value;
          data[coord + 3] = 255;
        }
      }

      yield ThreadPackage(index: index, data: data);
    }
  }
}
