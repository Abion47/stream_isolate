import 'dart:async';
import 'dart:isolate';

abstract class StreamIsolateBase<T> {
  StreamIsolateBase._(this._innerIsolate) : _controller = StreamController<T>();
  StreamIsolateBase._broadcast(this._innerIsolate)
      : _controller = StreamController<T>.broadcast();

  final Isolate _innerIsolate;
  final StreamController<T> _controller;

  StreamSink<T> get sink => _controller.sink;
  Stream<T> get stream => _controller.stream;

  List<ReceivePort> _portsToClose = [];
  List<StreamSubscription> _streamsToClose = [];

  void close() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }

    for (final port in _portsToClose) {
      port.close();
    }

    for (final sub in _streamsToClose) {
      await sub.cancel();
    }

    _streamsToClose.clear();
  }

  // Isolate Wrappers
  Stream get errors => _innerIsolate.errors;

  void addErrorListener(SendPort port) => _innerIsolate.addErrorListener(port);

  void addOnExitListener(SendPort responsePort, {Object? response}) =>
      _innerIsolate.addOnExitListener(responsePort, response: response);

  void kill({int priority = Isolate.beforeNextEvent}) {
    close();
    _innerIsolate.kill(priority: priority);
  }

  Capability pause([Capability? resumeCapability]) =>
      _innerIsolate.pause(resumeCapability);

  void ping(
    SendPort responsePort, {
    Object? response,
    int priority = Isolate.immediate,
  }) =>
      _innerIsolate.ping(responsePort, response: response, priority: priority);

  void removeErrorListener(SendPort port) =>
      _innerIsolate.removeErrorListener(port);

  void removeOnExitListener(SendPort responsePort) =>
      _innerIsolate.removeOnExitListener(responsePort);

  void resume(Capability resumeCapability) =>
      _innerIsolate.resume(resumeCapability);

  void setErrorsFatal(bool errorsAreFatal) =>
      _innerIsolate.setErrorsFatal(errorsAreFatal);

  @override
  String toString() => _innerIsolate.toString();
}

class StreamIsolate<T> extends StreamIsolateBase<T> {
  StreamIsolate._(Isolate isolate) : super._(isolate);
  StreamIsolate._broadcast(Isolate isolate) : super._broadcast(isolate);

  /// Creates and spawns an isolate that shares the same code as the current isolate.
  ///
  /// The argument `entryPoint` specifies the initial function to call in the spawned isolate. The entry-point function is invoked in the new isolate with `message` as the only argument.
  ///
  /// The function must be a top-level function or a static method that can be called with a single argument, that is, a compile-time constant function value which accepts at least one positional parameter and has at most one required positional parameter. The function may accept any number of optional parameters, as long as it can be called with just a single argument. The function must not be the value of a function expression or an instance method tear-off.
  ///
  /// The function must return a `Stream<T>` to publish messages to the main thread. (This is most easily accomplished with an `async*` generator.) **Note that messages sent by the spawned isolate before the main isolate has listened to the stream may not be received by the main isolate.**
  ///
  /// If the paused parameter is set to true, the isolate will start up in a paused state, just before calling the entryPoint function with the message, as if by an initial call of isolate.pause(isolate.pauseCapability). To resume the isolate, call isolate.resume(isolate.pauseCapability).
  ///
  /// If the errorsAreFatal, onExit and/or onError parameters are provided, the isolate will act as if, respectively, setErrorsFatal, addOnExitListener and addErrorListener were called with the corresponding parameter and was processed before the isolate starts running.
  ///
  /// If debugName is provided, the spawned Isolate will be identifiable by this name in debuggers and logging.
  ///
  /// If errorsAreFatal is omitted, the platform may choose a default behavior or inherit the current isolate's behavior.
  ///
  /// You can also call the setErrorsFatal, addOnExitListener and addErrorListener methods on the returned isolate, but unless the isolate was started as paused, it may already have terminated before those methods can complete.
  ///
  /// Returns a future which will complete with a StreamIsolate instance if the spawning succeeded. It will complete with an error otherwise.
  ///
  /// One can expect the base memory overhead of an isolate to be in the order of 30 kb.
  static Future<StreamIsolate<T>> spawn<T>(
    Stream<T> Function(dynamic) entryPoint, {
    Object? argument,
    bool paused = false,
    bool errorsAreFatal = true,
    String? debugName,
    bool broadcast = false,
  }) async {
    final isolateToMain = ReceivePort();

    final isolate = await Isolate.spawn<List<Object?>>(
      _isolateEntryPoint<T>,
      [entryPoint, isolateToMain.sendPort, argument],
      paused: paused,
      errorsAreFatal: errorsAreFatal,
      debugName: debugName,
    );

    StreamIsolate<T> streamIsolate;
    if (broadcast) {
      streamIsolate = StreamIsolate<T>._broadcast(isolate);
    } else {
      streamIsolate = StreamIsolate<T>._(isolate);
    }

    final isolateToMainListener = isolateToMain.listen((Object? message) {
      streamIsolate._controller.sink.add(message as T);
    });

    final errorPort = ReceivePort();
    isolate.addErrorListener(errorPort.sendPort);
    final errorListener = errorPort.listen((dynamic message) {
      streamIsolate._controller.addError(message as Object);
    });

    final closePort = ReceivePort();
    isolate.addOnExitListener(closePort.sendPort);
    final closeListener = closePort.listen((dynamic message) {
      streamIsolate.close();
    });

    streamIsolate._portsToClose = [
      isolateToMain,
      errorPort,
      closePort,
    ];
    streamIsolate._streamsToClose = [
      isolateToMainListener,
      errorListener,
      closeListener,
    ];

    return streamIsolate;
  }

  static void _isolateEntryPoint<T>(List<Object?> args) async {
    final entryPoint = args[0] as Stream<T> Function(dynamic);
    final isolateToMain = args[1] as SendPort;
    final argument = args[2];

    final stream = entryPoint(argument);
    await for (final message in stream) {
      isolateToMain.send(message);
    }
  }

  /// Creates and spawns an isolate that shares the same code as the current isolate.
  ///
  /// The argument `entryPoint` specifies the initial function to call in the spawned isolate. The entry-point function is invoked in the new isolate with a stream of incoming messages from the main isolate as the first argument and `message` as the second argument.
  ///
  /// The function must be a top-level function or a static method, that is, a compile-time constant function value which accepts at least two positional parameters and has at most two required positional parameters. The function may accept any number of optional parameters, as long as it can be called with just two arguments. The function must not be the value of a function expression or an instance method tear-off.
  ///
  /// Within the function, the passed stream should be listened to in order to receive messages coming from the main isolate. **Note that messages sent by the main isolate before the spawned isolate has listened to the stream may not be received by the spawned isolate.**
  ///
  /// The function must return a `Stream<T>` to publish messages to the main thread. (This is most easily accomplished with an `async*` generator.) **Note that messages sent by the spawned isolate before the main isolate has listened to the stream may not be received by the main isolate.**
  ///
  /// If the paused parameter is set to true, the isolate will start up in a paused state, just before calling the entryPoint function with the message, as if by an initial call of isolate.pause(isolate.pauseCapability). To resume the isolate, call isolate.resume(isolate.pauseCapability).
  ///
  /// If the errorsAreFatal, onExit and/or onError parameters are provided, the isolate will act as if, respectively, setErrorsFatal, addOnExitListener and addErrorListener were called with the corresponding parameter and was processed before the isolate starts running.
  ///
  /// If debugName is provided, the spawned Isolate will be identifiable by this name in debuggers and logging.
  ///
  /// If errorsAreFatal is omitted, the platform may choose a default behavior or inherit the current isolate's behavior.
  ///
  /// You can also call the setErrorsFatal, addOnExitListener and addErrorListener methods on the returned isolate, but unless the isolate was started as paused, it may already have terminated before those methods can complete.
  ///
  /// Returns a future which will complete with a StreamIsolate instance if the spawning succeeded. It will complete with an error otherwise.
  ///
  /// One can expect the base memory overhead of an isolate to be in the order of 30 kb.
  static Future<BidirectionalStreamIsolate<TIn, TOut>>
      spawnBidirectional<TIn, TOut>(
    Stream<TOut> Function(Stream<TIn>, dynamic) entryPoint, {
    Object? argument,
    bool paused = false,
    bool errorsAreFatal = true,
    String? debugName,
    bool broadcast = false,
  }) async {
    final isolateToMain = ReceivePort();

    final isolate = await Isolate.spawn<List<Object?>>(
      _isolateEntryPointBidirectional<TIn, TOut>,
      [entryPoint, isolateToMain.sendPort, argument],
      paused: paused,
      errorsAreFatal: errorsAreFatal,
      debugName: debugName,
    );

    BidirectionalStreamIsolate<TIn, TOut> streamIsolate;
    if (broadcast) {
      streamIsolate = BidirectionalStreamIsolate<TIn, TOut>._broadcast(isolate);
    } else {
      streamIsolate = BidirectionalStreamIsolate<TIn, TOut>._(isolate);
    }

    final isolateToMainListener = isolateToMain.listen((dynamic message) {
      if (message is SendPort) {
        final mainToIsolateSend = message;
        streamIsolate._input.stream.listen((event) {
          mainToIsolateSend.send(event);
        });
      } else {
        streamIsolate._controller.sink.add(message as TOut);
      }
    });

    final errorPort = ReceivePort();
    isolate.addErrorListener(errorPort.sendPort);
    final errorListener = errorPort.listen((dynamic message) {
      streamIsolate._controller.addError(message as Object);
    });

    final closePort = ReceivePort();
    isolate.addOnExitListener(closePort.sendPort);
    final closeListener = closePort.listen((dynamic message) {
      streamIsolate.close();
    });

    streamIsolate._portsToClose = [
      isolateToMain,
      errorPort,
      closePort,
    ];
    streamIsolate._streamsToClose = [
      isolateToMainListener,
      errorListener,
      closeListener,
    ];

    return streamIsolate;
  }

  static void _isolateEntryPointBidirectional<TIn, TOut>(
    List<Object?> args,
  ) async {
    final entryPoint = args[0] as Stream<TOut> Function(Stream<TIn>, dynamic);
    final isolateToMain = args[1] as SendPort;
    final argument = args[2];

    final mainToIsolate = ReceivePort();
    isolateToMain.send(mainToIsolate.sendPort);

    final controller = StreamController<TIn>();
    mainToIsolate.listen((dynamic message) {
      controller.add(message as TIn);
    });

    try {
      final stream = entryPoint(controller.stream, argument);
      await for (final message in stream) {
        isolateToMain.send(message);
      }
    } finally {
      mainToIsolate.close();
      controller.close();
    }
  }
}

class BidirectionalStreamIsolate<TIn, TOut> extends StreamIsolate<TOut> {
  BidirectionalStreamIsolate._(Isolate isolate)
      : _input = StreamController(),
        super._(isolate);

  BidirectionalStreamIsolate._broadcast(Isolate isolate)
      : _input = StreamController(),
        super._broadcast(isolate);

  final StreamController<TIn> _input;
  StreamSink<TIn> get inputSink => _input.sink;

  void send(TIn message) {
    _input.add(message);
  }

  @override
  void close() {
    if (!_input.isClosed) {
      _input.close();
    }

    super.close();
  }
}
