import 'dart:async';

Future<void> wait(int ms) => Future.delayed(Duration(milliseconds: ms));

Future<void> sendMessagesInOrder<T>(
  List<T> messages,
  void Function(T) sender,
) async {
  for (final msg in messages) {
    await wait(100);
    sender(msg);
  }
}

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

Stream<int> doWorkInt() async* {
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

Stream<int> doWorkIntWithArg(int x) async* {
  await wait(100);
  yield 1 + x;
  await wait(100);
  yield 2 + x;
  await wait(100);
  yield 3 + x;
  await wait(100);
  yield 4 + x;
  await wait(100);
  yield 5 + x;
}

Stream<String> doWorkString() async* {
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

Stream<CustomType> doWorkCustomType() async* {
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

Stream<int> doWorkWithError() async* {
  await wait(100);
  yield 1;
  await wait(100);
  yield 2;
  await wait(100);
  throw StateError('some error');
}

Stream<int> doBidirectionalWorkStringInt(
  Stream<String> incoming,
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

Stream<int> doBidirectionalWorkStringIntWithArgument(
  Stream<String> incoming,
  int argument,
) {
  final responseStream = StreamController<int>();
  incoming.listen((msg) {
    responseStream.add(msg.hashCode + argument);
    if (msg == 'e') {
      responseStream.close();
    }
  });

  return responseStream.stream;
}

Stream<CustomType> doBidirectionalWorkStringCustomType(
  Stream<String> incoming,
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
) {
  final responseStream = StreamController<int>();
  incoming.listen((msg) {
    if (msg == 'c') throw StateError('some error');
    responseStream.add(msg.hashCode);
  }, onError: (Object e) {
    throw e;
  });
  return responseStream.stream;
}
