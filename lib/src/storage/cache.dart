/// LRU cache implementation for Logseq data
library;

import 'dart:collection';

/// Least Recently Used (LRU) cache
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  LRUCache(this.maxSize);

  /// Get value from cache
  V? get(K key) {
    if (!_cache.containsKey(key)) return null;

    // Move to end (most recently used)
    final value = _cache.remove(key)!;
    _cache[key] = value;
    return value;
  }

  /// Put value in cache
  void put(K key, V value) {
    // Remove if exists
    _cache.remove(key);

    // Add to end (most recently used)
    _cache[key] = value;

    // Evict oldest if over capacity
    if (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Remove from cache
  void remove(K key) {
    _cache.remove(key);
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
  }

  /// Check if key exists in cache
  bool containsKey(K key) => _cache.containsKey(key);

  /// Get current cache size
  int get size => _cache.length;

  /// Get all keys in cache
  Iterable<K> get keys => _cache.keys;

  /// Get all values in cache
  Iterable<V> get values => _cache.values;
}

/// Cache manager for Logseq entities
class LogseqCache {
  final LRUCache<String, Map<String, dynamic>> _pageCache;
  final LRUCache<String, Map<String, dynamic>> _blockCache;

  LogseqCache({
    int maxPages = 100,
    int maxBlocks = 1000,
  })  : _pageCache = LRUCache(maxPages),
        _blockCache = LRUCache(maxBlocks);

  // Page cache operations
  Map<String, dynamic>? getPage(String name) => _pageCache.get(name);
  void putPage(String name, Map<String, dynamic> page) => _pageCache.put(name, page);
  void removePage(String name) => _pageCache.remove(name);
  bool hasPage(String name) => _pageCache.containsKey(name);

  // Block cache operations
  Map<String, dynamic>? getBlock(String id) => _blockCache.get(id);
  void putBlock(String id, Map<String, dynamic> block) => _blockCache.put(id, block);
  void removeBlock(String id) => _blockCache.remove(id);
  bool hasBlock(String id) => _blockCache.containsKey(id);

  // Bulk operations
  void invalidateAll() {
    _pageCache.clear();
    _blockCache.clear();
  }

  void invalidatePage(String pageName) {
    _pageCache.remove(pageName);
    // Also invalidate all blocks from this page
    // Note: This is a simple approach; could be optimized with a page->blocks index
  }

  // Statistics
  Map<String, int> getStats() {
    return {
      'pages': _pageCache.size,
      'blocks': _blockCache.size,
      'maxPages': _pageCache.maxSize,
      'maxBlocks': _blockCache.maxSize,
    };
  }
}
