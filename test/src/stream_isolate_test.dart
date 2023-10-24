@Timeout(Duration(seconds: 2))

import 'package:stream_isolate/stream_isolate.dart';
import 'package:test/test.dart';

import '../common.dart';

void main() {
  group('Unidirectional Isolates', () {
    test('Start isolate receiving ints', () async {
      final isolate = await StreamIsolate.spawn<int>(doWorkInt);
      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>[1, 2, 3, 4, 5, emitsDone],
        ),
      );
    });

    test('Start isolate receiving strings', () async {
      final isolate = await StreamIsolate.spawn<String>(doWorkString);
      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>['a', 'b', 'c', 'd', 'e', emitsDone],
        ),
      );
    });

    test('Start isolate receiving custom types', () async {
      final isolate = await StreamIsolate.spawn<CustomType>(doWorkCustomType);
      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>[
            const CustomType(1, 'a', false),
            const CustomType(2, 'b', false),
            const CustomType(3, 'c', false),
            const CustomType(4, 'd', true),
            const CustomType(5, 'e', true),
            emitsDone,
          ],
        ),
      );
    });
    test('Start isolate receiving ints with initial argument', () async {
      final isolate = await StreamIsolate.spawnWithArgument<int, int>(
        doWorkIntWithArg,
        argument: 1,
      );
      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>[2, 3, 4, 5, 6, emitsDone],
        ),
      );
    });

    test('Broadcast isolates stream to all listeners', () async {
      final expectedResponses = [1, 2, 3, 4, 5];
      final responses = <int>[];

      final isolate = await StreamIsolate.spawn<int>(
        doWorkInt,
        broadcast: true,
      );
      isolate.stream.listen((event) => event);
      isolate.stream.listen((event) => responses.add(event));

      await expectLater(
        isolate.stream,
        emitsInOrder(<dynamic>[...expectedResponses, emitsDone]),
      );

      expect(responses, orderedEquals(expectedResponses));
    });

    test('Streams propagate errors correctly', () async {
      final isolate =
          await StreamIsolate.spawn<int>(doWorkWithError, broadcast: true);

      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>[
            1,
            2,
            emitsError(allOf(isList, contains('Bad state: some error'))),
            emitsDone,
          ],
        ),
      );
    });
  });

  group('Bidirectional Isolates', () {
    test('Start isolate sending strings and receiving ints', () async {
      final isolate = await BidirectionalStreamIsolate.spawn<String, int>(
          doBidirectionalWorkStringInt);
      sendMessagesInOrder<String>(['a', 'b', 'c', 'd', 'e'], (msg) {
        isolate.send(msg);
      });

      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>[
            'a'.hashCode,
            'b'.hashCode,
            'c'.hashCode,
            'd'.hashCode,
            'e'.hashCode,
            emitsDone,
          ],
        ),
      );
    });

    test('Start isolate sending strings and receiving custom types', () async {
      final isolate =
          await BidirectionalStreamIsolate.spawn<String, CustomType>(
              doBidirectionalWorkStringCustomType);
      sendMessagesInOrder<String>(['a', 'b', 'c', 'd', 'e'], (msg) {
        isolate.send(msg);
      });

      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>[
            const CustomType(1, 'a', false),
            const CustomType(2, 'b', false),
            const CustomType(3, 'c', false),
            const CustomType(4, 'd', false),
            const CustomType(5, 'e', false),
            emitsDone,
          ],
        ),
      );
    });

    test(
        'Start isolate sending strings and receiving ints with initial argument',
        () async {
      final isolate =
          await BidirectionalStreamIsolate.spawnWithArgument<String, int, int>(
        doBidirectionalWorkStringIntWithArgument,
        argument: 1,
      );
      sendMessagesInOrder<String>(['a', 'b', 'c', 'd', 'e'], (msg) {
        isolate.send(msg);
      });

      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>[
            'a'.hashCode + 1,
            'b'.hashCode + 1,
            'c'.hashCode + 1,
            'd'.hashCode + 1,
            'e'.hashCode + 1,
            emitsDone,
          ],
        ),
      );
    });

    test('Broadcast isolates stream to all listeners', () async {
      final expectedResponses = [
        'a'.hashCode,
        'b'.hashCode,
        'c'.hashCode,
        'd'.hashCode,
        'e'.hashCode,
      ];
      final responses = <int>[];

      final isolate = await BidirectionalStreamIsolate.spawn<String, int>(
        doBidirectionalWorkStringInt,
        broadcast: true,
      );
      isolate.stream.listen((event) => event);
      isolate.stream.listen((event) => responses.add(event));

      sendMessagesInOrder<String>(['a', 'b', 'c', 'd', 'e'], (msg) {
        isolate.send(msg);
      });

      await expectLater(
        isolate.stream,
        emitsInOrder(<dynamic>[...expectedResponses, emitsDone]),
      );

      expect(responses, orderedEquals(expectedResponses));
    });

    test('Bidirectional streams propagate errors correctly', () async {
      final isolate = await BidirectionalStreamIsolate.spawn<String, int>(
          doBidirectionalWorkWithError);
      sendMessagesInOrder<String>(['a', 'b', 'c'], (msg) {
        isolate.send(msg);
      });

      expect(
        isolate.stream,
        emitsInOrder(
          <dynamic>[
            'a'.hashCode,
            'b'.hashCode,
            emitsError(allOf(isList, contains('Bad state: some error'))),
            emitsDone,
          ],
        ),
      );
    });
  });
}
