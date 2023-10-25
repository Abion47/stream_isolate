import 'dart:async';

import 'package:stream_isolate/stream_isolate.dart';

void main() async {
  // Create normal isolate
  final streamIsolate = await StreamIsolate.spawn(doWork);

  // Listen for isolate responses
  streamIsolate.stream.listen((i) {
    print('main: $i');
  });

  // Create isolate with bidirectional communiucation
  final bidirectionalStreamIsolate =
      await BidirectionalStreamIsolate.spawn(doWorkWithListener);

  // Listen for bidirectional isolate responses
  bidirectionalStreamIsolate.stream.listen((i) {
    print('main (bi): $i');
  });

  // Send messages to the bidirectional isolate
  sendMessages(bidirectionalStreamIsolate);

  // Wait for all isolates to complete
  await Future.wait([
    streamIsolate.getIsClosedFuture(),
    bidirectionalStreamIsolate.getIsClosedFuture(),
  ]);

  // Signal that the program has completed
  print('Done');
}

Stream<int> doWork() async* {
  yield 0;
  await wait(100);
  yield 1;
  await wait(100);
  yield 2;
  await wait(100);
  yield 3;
  await wait(100);
  yield 4;
  await wait(100);
  yield 5;
}

Stream<int> doWorkWithListener(Stream<String> inc) async* {
  inc.listen((msg) => print('isolate (bi): $msg'));

  yield 0;
  await wait(100);
  yield 1;
  await wait(100);
  yield 2;
  await wait(100);
  yield 3;
  await wait(100);
  yield 4;
  await wait(100);
  yield 5;
}

Future<void> wait(int ms) => Future.delayed(Duration(milliseconds: ms));

void sendMessages(BidirectionalStreamIsolate<String, int, void> isolate) async {
  await wait(50);
  isolate.send('a');
  await wait(100);
  isolate.send('b');
  await wait(100);
  isolate.send('c');
  await wait(100);
  isolate.send('d');
  await wait(100);
  isolate.send('e');
}
