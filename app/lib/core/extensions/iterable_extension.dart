/// Extension methods for [Iterable].
extension IterableExtension<T> on Iterable<T> {
  /// Returns the first element matching [test], or null if none found.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  /// Returns the last element matching [test], or null if none found.
  T? lastWhereOrNull(bool Function(T element) test) {
    T? result;
    for (final element in this) {
      if (test(element)) result = element;
    }
    return result;
  }

  /// Maps each element and its index to a new value.
  Iterable<R> mapIndexed<R>(R Function(int index, T element) convert) sync* {
    var index = 0;
    for (final element in this) {
      yield convert(index++, element);
    }
  }

  /// Separates elements with a separator.
  Iterable<T> separated(T separator) sync* {
    var first = true;
    for (final element in this) {
      if (!first) yield separator;
      first = false;
      yield element;
    }
  }
}
