import 'dart:math';

import 'package:rxdart/rxdart.dart';
import 'package:stream_isolate/stream_isolate.dart';

// This program will take roughly the same amount of time to run regardless of
// how many isolates are spawned (to a point, of course)
const isolateCount = 4;

void main() async {
  // Create many parallel isolates and join the streams into one
  final notificationStream = await createParallelStreams(
    handler: handler,
    count: isolateCount,
  );

  // Listen for a response from any of the created isolates
  int idx = 1;
  notificationStream.listen((event) {
    print('$idx: $event');
    idx++;
  });
}

Future<Stream<T>> createParallelStreams<T>({
  required Stream<T> Function() handler,
  required int count,
}) async {
  final streams = <Stream<T>>[];

  for (int i = 0; i < count; i++) {
    // Spawn an isolate and cache the stream
    final isolate = await StreamIsolate.spawn(handler);
    streams.add(isolate.stream);
  }

  // Use RxDart `MergeStream` to join the isolate streams into one
  return MergeStream(streams);
}

Future<void> wait(int ms) => Future.delayed(Duration(milliseconds: ms));

Stream<String> handler() async* {
  final random = Random();

  const maxInt = 0xFFFFFFFF;

  const iterations = 10;
  const minWait = 50;
  const maxWait = 500;

  for (int i = 0; i < iterations; i++) {
    // Simulate working process
    final waitMs = random.nextInt(maxWait - minWait) + minWait;
    await wait(waitMs);

    // Generate "random" 256-bit hash
    yield List.generate(8, (_) => random.nextInt(maxInt))
        .map((e) => e.toRadixString(16).padLeft(8, '0'))
        .join();
  }
}
