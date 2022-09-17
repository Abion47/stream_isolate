[![pub package](https://img.shields.io/pub/v/stream_isolate.svg)](https://pub.dartlang.org/packages/stream_isolate)
[![github stars](https://img.shields.io/github/stars/abion47/stream_isolate.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/abion47/stream_isolate)
[![license MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

A wrapper class for `Isolate` that exposes a communication channel using a `Stream`.

## API Reference

 - [Dart Docs](https://pub.dev/documentation/stream_isolate/latest/stream_isolate/stream_isolate-library.html)

## Usage

To use, call `StreamIsolate.spawn` with the same types of arguments passed to `Isolate.spawn`. You can then use the returned instance to subscribe to events published by the isolate:

```dart
final streamIsolate = await StreamIsolate.spawn<int>(doWork);
await for (final i in streamIsolate.stream) {
  print(i);
}
```

```dart
Stream<int> doWork(_) async* {
  yield 1;
  yield 2;
  yield 3;
  yield 4;
  yield 5;
}
```

You can also call `StreamIsolate.spawnBidirectional` to create an isolate that exposes an additional communication stream for sending messages to the instance:

```dart
final streamIsolate = await StreamIsolate.spawnBidirectional<String, int>(doWork);
await for (final i in streamIsolate.stream) {
  print(i);
  streamIsolate.send('received');
}
```

```dart
Stream<int> doWorkWithListener(Stream<String> inc, _) async* {
  inc.listen((msg) => print('from main: $msg'));

  yield 1;
  yield 2;
  yield 3;
  yield 4;
  yield 5;
}
```