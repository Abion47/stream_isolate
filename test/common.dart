import 'dart:async';

Future<void> wait(int ms) => Future.delayed(Duration(milliseconds: ms));

class CustomType {
  final int a;
  final String b;
  final bool c;

  const CustomType(this.a, this.b, this.c);

  @override
  bool operator ==(Object? other) {
    if (other is! CustomType) return false;
    return a == other.a && b == other.b && c == other.c;
  }

  @override
  int get hashCode => a.hashCode ^ b.hashCode ^ c.hashCode;
}

Stream<int> doWorkInt(Object? arguments) async* {
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

Stream<String> doWorkString(Object? arguments) async* {
  await wait(100);
  yield 'a';
  await wait(100);
  yield 'b';
  await wait(100);
  yield 'c';
  await wait(100);
  yield 'd';
  await wait(100);
  yield 'e';
}

Stream<CustomType> doWorkCustomType(Object? arguments) async* {
  await wait(100);
  yield const CustomType(1, 'a', false);
  await wait(100);
  yield const CustomType(2, 'b', false);
  await wait(100);
  yield const CustomType(3, 'c', false);
  await wait(100);
  yield const CustomType(4, 'd', true);
  await wait(100);
  yield const CustomType(5, 'e', true);
}

Stream<int> doWorkWithError(Object? arguments) async* {
  await wait(100);
  yield 1;
  await wait(100);
  yield 2;
  await wait(100);
  throw StateError('some error');
}

Future<void> sendMessagesInOrder<T>(
  StreamSink<T> sink,
  List<T> messages,
) async {
  for (final msg in messages) {
    await wait(100);
    sink.add(msg);
  }
}

Stream<int> doBidirectionalWorkStringInt(
  Stream<String> incoming,
  Object? arguments,
) {
  final responseStream = StreamController<int>();
  incoming.listen((msg) {
    responseStream.add(msg.hashCode);
    if (msg == 'e') {
      responseStream.close();
    }
  });

  return responseStream.stream;
}

Stream<CustomType> doBidirectionalWorkStringCustomType(
  Stream<String> incoming,
  Object? arguments,
) {
  final responseStream = StreamController<CustomType>();
  var index = 1;
  incoming.listen((msg) {
    responseStream.add(CustomType(index++, msg, false));
    if (msg == 'e') {
      responseStream.close();
    }
  });
  return responseStream.stream;
}

Stream<int> doBidirectionalWorkWithError(
  Stream<String> incoming,
  Object? arguments,
) {
  final responseStream = StreamController<int>();
  incoming.listen((msg) {
    if (msg == 'c') throw StateError('some error');
    responseStream.add(msg.hashCode);
  });
  return responseStream.stream;
}
