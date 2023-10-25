[![pub package](https://img.shields.io/pub/v/stream_isolate.svg)](https://pub.dartlang.org/packages/stream_isolate)
[![github stars](https://img.shields.io/github/stars/abion47/stream_isolate.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/abion47/stream_isolate)
[![license MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://github.com/abion47/stream_isolate/workflows/Dart/badge.svg)](https://github.com/abion47/stream_isolate/actions)
[![Code Coverage](https://codecov.io/gh/abion47/stream_isolate/branch/main/graph/badge.svg)](https://codecov.io/gh/abion47/stream_isolate)

A wrapper class for `Isolate` that exposes a communication channel using a `Stream`.

## API Reference

 - [Dart Docs](https://pub.dev/documentation/stream_isolate/latest/stream_isolate/stream_isolate-library.html)

## Basic Usage

To use, call `StreamIsolate.spawn` with the same types of arguments passed to `Isolate.spawn`. You can then use the returned instance to subscribe to events published by the isolate:

```dart
final streamIsolate = await StreamIsolate.spawn(doWork);
await for (final i in streamIsolate.stream) {
  print(i);
}
```

```dart
Stream<int> doWork() async* {
  yield 1;
  yield 2;
  yield 3;
  yield 4;
  yield 5;
}
```

## Bidirectional Communication

You can also call `BidirectionalStreamIsolate.spawn` (or `StreamIsolate.spawnBidirectional`) to create an isolate that exposes an additional communication stream for sending messages to the instance:

```dart
final streamIsolate = await BidirectionalStreamIsolate.spawn(doWork);
await for (final i in streamIsolate.stream) {
  print(i);
  streamIsolate.send('received');
}
```

```dart
Stream<int> doWorkWithListener(Stream<String> inc) async* {
  inc.listen((msg) => print('from main: $msg'));

  yield 1;
  yield 2;
  yield 3;
  yield 4;
  yield 5;
}
```

## Passing Initial Arguments

You can optionally send an argument that gets passed to the thread function when it first runs. This is done using the `StreamIsolate.spawnWithArgument` and `BidirectionalStreamIsolate.spawnWithArgument` methods.

```dart
class IsolateArgs {
  final int index;
  final String name;

  const IsolateArgs(this.index, this.name);
}

...

final args = IsolateArgs(1, 'Worker Isolate 1');
final streamIsolate = await StreamIsolate.spawnWithArgument(doWork, argument: args);
await for (final i in streamIsolate.stream) {
  print(i);
  streamIsolate.send('received');
}
```

```dart
Stream<int> doWorkWithListener(Stream<String> inc, IsolateArgs args) async* {
  print('Starting worker isolate ${args.name}, Index: ${args.index}');

  yield 1;
  yield 2;
  yield 3;
  yield 4;
  yield 5;
}
```

## Examples

* [Vanilla](https://github.com/Abion47/stream_isolate/tree/main/examples/vanilla) - A simple example of using stream isolates.
* [Multithreaded Noise](https://github.com/Abion47/stream_isolate/tree/main/examples/multithreaded_noise) - An example of a Flutter app using stream isolates to generate animated Perlin Noise.