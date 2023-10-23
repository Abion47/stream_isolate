import 'dart:async';
import 'dart:isolate';

abstract class _StreamIsolateBase<T> {
  _StreamIsolateBase._(this._innerIsolate)
      : _controller = StreamController<T>();
  _StreamIsolateBase._broadcast(this._innerIsolate)
      : _controller = StreamController<T>.broadcast();

  final Isolate _innerIsolate;
  final StreamController<T> _controller;

  Stream<T> get stream => _controller.stream;

  List<ReceivePort> _portsToClose = [];
  List<StreamSubscription> _streamsToClose = [];

  /// Sends the kill command to the isolate and closes all streams associated
  /// with the connection.
  Future<void> close() async {
    for (final port in _portsToClose) {
      port.close();
    }

    for (final sub in _streamsToClose) {
      await sub.cancel();
    }

    _portsToClose.clear();
    _streamsToClose.clear();

    if (!_controller.isClosed) {
      _controller.close();
      _innerIsolate.kill();
    }
  }

  /// Control port used to send control messages to the isolate.
  ///
  /// The control port identifies the isolate.
  ///
  /// An `Isolate` object allows sending control messages through the control port.
  ///
  /// Some control messages require a specific capability to be passed along with
  /// the message (see `pauseCapability` and `terminateCapability`), otherwise
  /// the message is ignored by the isolate.
  SendPort get controlPort => _innerIsolate.controlPort;

  /// The name of the `Isolate` displayed for debug purposes.
  ///
  /// This can be set using the `debugName` parameter in `spawn` and `spawnUri`.
  ///
  /// This name does not uniquely identify an isolate. Multiple isolates in the
  /// same process may have the same debugName.
  ///
  /// For a given isolate, this value will be the same as the values returned by
  /// `Dart_DebugName` in the C embedding API and the debugName property in
  /// `IsolateMirror`.
  String? get debugName => _innerIsolate.debugName;

  /// Returns a broadcast stream of uncaught errors from the isolate.
  ///
  /// Each error is provided as an error event on the stream.
  ///
  /// The actual error object and stackTraces will not necessarily be the same
  /// object types as in the actual isolate, but they will always have the same
  /// `Object.toString` result.
  ///
  /// This stream is based on `addErrorListener` and `removeErrorListener`.
  Stream get errors => _innerIsolate.errors;

  /// Capability granting the ability to pause the isolate.
  ///
  /// This capability is required by `pause`. If the capability is `null`, or if
  /// it is not the correct pause capability of the isolate identified by
  /// `controlPort`, then calls to `pause` will have no effect.
  ///
  /// If the isolate is spawned in a paused state, use this capability as argument
  /// to the `resume` method in order to resume the paused isolate.
  Capability? get pauseCapability => _innerIsolate.pauseCapability;

  /// Capability granting the ability to terminate the isolate.
  ///
  /// This capability is required by `kill` and `setErrorsFatal`. If the capability
  /// is `null`, or if it is not the correct termination capability of the isolate
  /// identified by `controlPort`, then calls to those methods will have no effect.
  Capability? get terminateCapability => _innerIsolate.terminateCapability;

  /// Requests that uncaught errors of the isolate are sent back to `port`.
  ///
  /// The errors are sent back as two-element lists. The first element is a `String`
  /// representation of the error, usually created by calling `toString` on the
  /// error. The second element is a `String` representation of an accompanying
  /// stack trace, or `null` if no stack trace was provided. To convert this back
  /// to a `StackTrace` object, use `StackTrace.fromString`.
  ///
  /// Listening using the same port more than once does nothing. A port will only
  /// receive each error once, and will only need to be removed once using
  /// `removeErrorListener`.
  ///
  /// Closing the receive port that is associated with the port does not stop the
  /// isolate from sending uncaught errors, they are just going to be lost. Instead
  /// use `removeErrorListener` to stop receiving errors on port.
  ///
  /// Since isolates run concurrently, it's possible for it to exit before the
  /// error listener is established. To avoid this, start the isolate paused, add
  /// the listener and then resume the isolate.
  void addErrorListener(SendPort port) => _innerIsolate.addErrorListener(port);

  /// Requests an exit message on `responsePort` when the isolate terminates.
  ///
  /// The isolate will send response as a message on `responsePort` as the last
  /// thing before it terminates. It will run no further code after the message
  /// has been sent.
  ///
  /// Adding the same port more than once will only cause it to receive one exit
  /// message, using the last response value that was added, and it only needs
  /// to be removed once using `removeOnExitListener`.
  ///
  /// If the isolate has terminated before it can receive this request, no exit
  /// message will be sent.
  ///
  /// The `response` object must follow the same restrictions as enforced by
  /// `SendPort.send`. It is recommended to only use simple values that can be
  /// sent to all isolates, like `null`, booleans, numbers or strings.
  ///
  /// Since isolates run concurrently, it's possible for it to exit before the
  /// exit listener is established, and in that case no response will be sent on
  /// `responsePort`. To avoid this, either use the corresponding parameter to
  /// the spawn function, or start the isolate paused, add the listener and then
  /// resume the isolate.
  void addOnExitListener(SendPort responsePort, {Object? response}) =>
      _innerIsolate.addOnExitListener(responsePort, response: response);

  /// Requests the isolate to shut down.
  ///
  /// The isolate is requested to terminate itself. The `priority` argument
  /// specifies when this must happen.
  ///
  /// The priority, when provided, must be one of `immediate` or `beforeNextEvent`
  /// (the default). The shutdown is performed at different times depending on
  /// the priority:
  ///
  /// * `immediate`: The isolate shuts down as soon as possible. Control messages
  /// are handled in order, so all previously sent control events from this isolate
  /// will all have been processed. The shutdown should happen no later than if
  /// sent with `beforeNextEvent`. It may happen earlier if the system has a way
  /// to shut down cleanly at an earlier time, even during the execution of another
  /// event.
  /// * `beforeNextEvent`: The shutdown is scheduled for the next time control
  /// returns to the event loop of the receiving isolate, after the current event,
  /// and any already scheduled control events, are completed.
  ///
  /// If `terminateCapability` is `null`, or it's not the terminate capability of
  /// the isolate identified by `controlPort`, the kill request is ignored by the
  /// receiving isolate.
  void kill({int priority = Isolate.beforeNextEvent}) {
    close();
    _innerIsolate.kill(priority: priority);
  }

  /// Requests the isolate to pause.
  ///
  /// When the isolate receives the pause command, it stops processing events from
  /// the event loop queue. It may still add new events to the queue in response
  /// to, e.g., timers or receive-port messages. When the isolate is resumed, it
  /// starts handling the already enqueued events.
  ///
  /// The pause request is sent through the isolate's command port, which bypasses
  /// the receiving isolate's event loop. The pause takes effect when it is received,
  /// pausing the event loop as it is at that time.
  ///
  /// The `resumeCapability` is used to identity the pause, and must be used again
  /// to end the pause using `resume`. If `resumeCapability` is omitted, a new
  /// capability object is created and used instead.
  ///
  /// If an isolate is paused more than once using the same capability, only one
  /// resume with that capability is needed to end the pause.
  ///
  /// If an isolate is paused using more than one capability, each pause must be
  /// individually ended before the isolate resumes.
  ///
  /// Returns the capability that must be used to end the pause. This is either
  /// `resumeCapability`, or a new capability when `resumeCapability` is omitted.
  ///
  /// If `pauseCapability` is `null`, or it's not the pause capability of the
  /// isolate identified by `controlPort`, the pause request is ignored by the
  /// receiving isolate.
  Capability pause([Capability? resumeCapability]) =>
      _innerIsolate.pause(resumeCapability);

  /// Requests that the isolate send response on the `responsePort`.
  ///
  /// The `response` object must follow the same restrictions as enforced by
  /// `SendPort.send`. It is recommended to only use simple values that can be
  /// sent to all isolates, like `null`, booleans, numbers or strings.
  ///
  /// If the isolate is alive, it will eventually send response (defaulting to
  /// `null`) on the response port.
  ///
  /// The priority must be one of `immediate` or `beforeNextEvent`. The response
  /// is sent at different times depending on the ping type:
  ///
  /// * `immediate`: The isolate responds as soon as it receives the control message.
  /// This is after any previous control message from the same isolate has been
  /// received and processed, but may be during execution of another event.
  /// * `beforeNextEvent`: The response is scheduled for the next time control
  /// returns to the event loop of the receiving isolate, after the current event,
  /// and any already scheduled control events, are completed.
  void ping(
    SendPort responsePort, {
    Object? response,
    int priority = Isolate.immediate,
  }) =>
      _innerIsolate.ping(responsePort, response: response, priority: priority);

  /// Stops listening for uncaught errors from the isolate.
  ///
  /// Requests for the isolate to not send uncaught errors on `port`. If the
  /// isolate isn't expecting to send uncaught errors on port, because the port
  /// hasn't been added using `addErrorListener`, or because it has already been
  /// removed, the request is ignored.
  ///
  /// If the same port has been passed via `addErrorListener` more than once,
  /// only one call to `removeErrorListener` is needed to stop it from receiving
  /// uncaught errors.
  ///
  /// Uncaught errors message may still be sent by the isolate until this request
  /// is received and processed.
  void removeErrorListener(SendPort port) =>
      _innerIsolate.removeErrorListener(port);

  /// Stops listening for exit messages from the isolate.
  ///
  /// Requests for the isolate to not send exit messages on `responsePort`. If
  /// the isolate isn't expecting to send exit messages on `responsePort`, because
  /// the port hasn't been added using `addOnExitListener`, or because it has
  /// already been removed, the request is ignored.
  ///
  /// If the same port has been passed via `addOnExitListener` more than once,
  /// only one call to `removeOnExitListener` is needed to stop it from receiving
  /// exit messages.
  ///
  /// Closing the receive port that is associated with the `responsePort` does
  /// not stop the isolate from sending uncaught errors, they are just going to
  /// be lost.
  ///
  /// An exit message may still be sent if the isolate terminates before this
  /// request is received and processed.
  void removeOnExitListener(SendPort responsePort) =>
      _innerIsolate.removeOnExitListener(responsePort);

  /// Resumes a paused isolate.
  ///
  /// Sends a message to an isolate requesting that it ends a pause that was
  /// previously requested.
  ///
  /// When all active pause requests have been cancelled, the isolate will continue
  /// processing events and handling normal messages.
  ///
  /// If the `resumeCapability` is not one that has previously been used to pause
  /// the isolate, or it has already been used to resume from that pause, the
  /// resume call has no effect.
  void resume(Capability resumeCapability) =>
      _innerIsolate.resume(resumeCapability);

  /// Sets whether uncaught errors will terminate the isolate.
  ///
  /// If errors are fatal, any uncaught error will terminate the isolate event
  /// loop and shut down the isolate.
  ///
  /// This call requires the `terminateCapability` for the isolate. If the
  /// capability is absent or incorrect, no change is made.
  ///
  /// Since isolates run concurrently, it's possible for the receiving isolate
  /// to exit due to an error, before a request, using this method, has been
  /// received and processed. To avoid this, either use the corresponding
  /// parameter to the spawn function, or start the isolate paused, set errors
  /// non-fatal and then resume the isolate.
  void setErrorsFatal(bool errorsAreFatal) =>
      _innerIsolate.setErrorsFatal(errorsAreFatal);

  @override
  String toString() => _innerIsolate.toString();
}

class StreamIsolate<T> extends _StreamIsolateBase<T> {
  StreamIsolate._(Isolate isolate) : super._(isolate);
  StreamIsolate._broadcast(Isolate isolate) : super._broadcast(isolate);

  /// Creates and spawns an isolate that shares the same code as the current
  /// isolate.
  ///
  /// The argument `entryPoint` specifies the initial function to call in the
  /// spawned isolate. The entry-point function is invoked in the new isolate
  /// with `message` as the only argument.
  ///
  /// The function must be a top-level function or a static method that can be
  /// called with a single argument, that is, a compile-time constant function
  /// value which accepts at least one positional parameter and has at most one
  /// required positional parameter. The function may accept any number of optional
  /// parameters, as long as it can be called with just a single argument. The
  /// function must not be the value of a function expression or an instance
  /// method tear-off.
  ///
  /// The function must return a `Stream<T>` to publish messages to the main
  /// thread. (This is most easily accomplished with an `async*` generator.)
  /// **Note that messages sent by the spawned isolate before the main isolate
  /// has listened to the stream may not be received by the main isolate.**
  ///
  /// If the paused parameter is set to true, the isolate will start up in a
  /// paused state, just before calling the entryPoint function with the message,
  /// as if by an initial call of isolate.pause(isolate.pauseCapability). To
  /// resume the isolate, call isolate.resume(isolate.pauseCapability).
  ///
  /// If the errorsAreFatal, onExit and/or onError parameters are provided, the
  /// isolate will act as if, respectively, setErrorsFatal, addOnExitListener
  /// and addErrorListener were called with the corresponding parameter and was
  /// processed before the isolate starts running.
  ///
  /// If debugName is provided, the spawned Isolate will be identifiable by this
  /// name in debuggers and logging.
  ///
  /// If errorsAreFatal is omitted, the platform may choose a default behavior
  /// or inherit the current isolate's behavior.
  ///
  /// You can also call the setErrorsFatal, addOnExitListener and addErrorListener
  /// methods on the returned isolate, but unless the isolate was started as paused,
  /// it may already have terminated before those methods can complete.
  ///
  /// Returns a future which will complete with a StreamIsolate instance if the
  /// spawning succeeded. It will complete with an error otherwise.
  ///
  /// One can expect the base memory overhead of an isolate to be in the order
  /// of 30 kb.
  static Future<StreamIsolate<T>> spawn<T>(
    Stream<T> Function(Object? arguments) entryPoint, {
    Object? argument,
    bool paused = false,
    bool errorsAreFatal = true,
    String? debugName,
    bool broadcast = false,
  }) async {
    final isolateToMain = ReceivePort();
    final errorPort = ReceivePort();
    final closePort = ReceivePort();

    late StreamIsolate<T> streamIsolate;

    final isolateToMainListener = isolateToMain.listen((Object? message) {
      streamIsolate._controller.sink.add(message as T);
    });

    final errorListener = errorPort.listen((dynamic message) {
      streamIsolate._controller.addError(message as Object);
    });

    final closeListener = closePort.listen((dynamic message) async {
      await streamIsolate.close();
    });

    final isolate = await Isolate.spawn<List<Object?>>(
      _isolateEntryPoint<T>,
      [entryPoint, isolateToMain.sendPort, argument],
      paused: paused,
      errorsAreFatal: errorsAreFatal,
      debugName: debugName,
      onError: errorPort.sendPort,
      onExit: closePort.sendPort,
    );

    if (broadcast) {
      streamIsolate = StreamIsolate<T>._broadcast(isolate);
    } else {
      streamIsolate = StreamIsolate<T>._(isolate);
    }

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

  /// Creates and spawns an isolate that shares the same code as the current
  /// isolate.
  ///
  /// The argument `entryPoint` specifies the initial function to call in the
  /// spawned isolate. The entry-point function is invoked in the new isolate
  /// with a stream of incoming messages from the main isolate as the first
  /// argument and `message` as the second argument.
  ///
  /// The function must be a top-level function or a static method, that is, a
  /// compile-time constant function value which accepts at least two positional
  /// parameters and has at most two required positional parameters. The function
  /// may accept any number of optional parameters, as long as it can be called
  /// with just two arguments. The function must not be the value of a function
  /// expression or an instance method tear-off.
  ///
  /// Within the function, the passed stream should be listened to in order to
  /// receive messages coming from the main isolate. **Note that messages sent
  /// by the main isolate before the spawned isolate has listened to the stream
  /// may not be received by the spawned isolate.**
  ///
  /// The function must return a `Stream<T>` to publish messages to the main thread.
  /// (This is most easily accomplished with an `async*` generator.) **Note that
  /// messages sent by the spawned isolate before the main isolate has listened
  /// to the stream may not be received by the main isolate.**
  ///
  /// If the paused parameter is set to true, the isolate will start up in a paused
  /// state, just before calling the entryPoint function with the message, as if
  /// by an initial call of isolate.pause(isolate.pauseCapability). To resume the
  /// isolate, call isolate.resume(isolate.pauseCapability).
  ///
  /// If the errorsAreFatal, onExit and/or onError parameters are provided, the
  /// isolate will act as if, respectively, setErrorsFatal, addOnExitListener and
  /// addErrorListener were called with the corresponding parameter and was
  /// processed before the isolate starts running.
  ///
  /// If debugName is provided, the spawned Isolate will be identifiable by this
  /// name in debuggers and logging.
  ///
  /// If errorsAreFatal is omitted, the platform may choose a default behavior
  /// or inherit the current isolate's behavior.
  ///
  /// You can also call the setErrorsFatal, addOnExitListener and addErrorListener
  /// methods on the returned isolate, but unless the isolate was started as paused,
  /// it may already have terminated before those methods can complete.
  ///
  /// Returns a future which will complete with a StreamIsolate instance if the
  /// spawning succeeded. It will complete with an error otherwise.
  ///
  /// One can expect the base memory overhead of an isolate to be in the order
  /// of 30 kb.
  static Future<BidirectionalStreamIsolate<TIn, TOut>>
      spawnBidirectional<TIn, TOut>(
    Stream<TOut> Function(Stream<TIn> messageStream, Object? arguments)
        entryPoint, {
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
  Future<void> close() async {
    if (!_input.isClosed) {
      await _input.close();
    }

    await super.close();
  }
}
