import 'dart:async';

import 'package:stream_isolate/stream_isolate.dart';

Future<void> wait(int ms) => Future.delayed(Duration(milliseconds: ms));

void main() async {
  final streamIsolate =
      await StreamIsolate.spawnBidirectional<String, int>(doWorkWithListener);

  sendMessages(streamIsolate);

  // final streamIsolate = await StreamIsolate.spawn<int>(doWork);

  await for (final i in streamIsolate.stream) {
    print('main: $i');
  }

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

Stream<int> doWorkWithError() async* {
  yield 0;
  await wait(100);
  yield 1;
  await wait(100);
  throw StateError('error');
}

void sendMessages(
    BidirectionalStreamIsolate<String, int, dynamic> isolate) async {
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

Stream<int> doWorkWithListener(Stream<String> inc) async* {
  inc.listen((msg) => print('isolate: $msg'));

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
