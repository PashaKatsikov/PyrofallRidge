/// A tiny generic object pool.
///
/// Falling objects are spawned and retired frequently while the player
/// climbs, so reusing instances avoids per-frame/per-spawn allocations as
/// required by the performance guidelines.
class ObjectPool<T> {
  ObjectPool(this._factory, {this.maxIdle = 16});

  final T Function() _factory;
  final int maxIdle;
  final List<T> _idle = <T>[];

  T acquire() {
    if (_idle.isNotEmpty) {
      return _idle.removeLast();
    }
    return _factory();
  }

  void release(T instance) {
    if (_idle.length < maxIdle) {
      _idle.add(instance);
    }
  }
}
