## 0.2.0
* **Breaking Change**: `argument` removed from `StreamIsolate.spawn` and `StreamIsolate.spawnBidirectional` methods.
  * This also removes the potentially useless `Object? argument` parameter from the entry point function.
* **Important Change**: New static methods `spawnWithArgument` and `spawnBidirectionalWithArgument` added to `StreamIsolate` for strong typing of the entry point function `argument` parameter.
* Moved code for `StreamIsolate.spawnBidirectional` and `StreamIsolate.spawnBidirectionalWithArgs` static methods to `BidirectionalStreamIsolate.spawn` and `BidirectionalStreamIsolate.spawnWithArgument`, respectively. 
  * `StreamIsolate.spawnBidirectional` and `StreamIsolate.spawnBidirectionalWithArgs` static methods static methods remain as convenience wrapper methods.
* Added convenience method `BaseStreamIsolate.getIsClosedFuture` that returns a future which resolves when the isolate is stopped for any reason.
* Bumped Dart SDK range from '<3.0.0' to '<4.0.0' to explicitly support Dart 3.
* Fixed broadcast unit test to actually complete and confirm fix of known issue.
* Added unit tests for spawning isolates that pass an initial argument.
* Added an example of using RxDart to manage isolate communication.
* Added an example of a Flutter app using multi-threaded noise generation.

## 0.1.2
* Added unit tests, CI, and test coverage report

## 0.1.1
* Added more documentation from dart:async's `Isolate`.

## 0.1.0
* Initial version.
