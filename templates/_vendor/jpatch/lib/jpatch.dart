library jpatch;

// Pure-Dart shim of ArcaneArts/jpatch 1.0.1.
// API surface is intentionally identical so the published package and this
// shim are interchangeable as a pubspec `dependency_overrides` target.

bool flatEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  Map<String, dynamic> fa = flatMap(a);
  Map<String, dynamic> fb = flatMap(b);

  if (fa.length != fb.length) {
    return false;
  }

  for (final String key in fa.keys) {
    if (!fb.containsKey(key) || !eq(fb[key], fa[key])) {
      return false;
    }
  }

  return true;
}

List<String> flatDiff(Map<String, dynamic> a, Map<String, dynamic> b) {
  Map<String, dynamic> fa = flatMap(a);
  Map<String, dynamic> fb = flatMap(b);
  List<String> changes = <String>[];

  if (fa.length != fb.length) {
    changes.add("* length ${fa.length} -> ${fb.length}");
    return changes;
  }

  for (final String key in fa.keys) {
    if (!fb.containsKey(key)) {
      changes.add("* Key change $key");
    } else if (!eq(fb[key], fa[key])) {
      changes.add("* $key [${fa[key]} -> ${fb[key]}]");
    }
  }

  return changes;
}

bool eq(dynamic a, dynamic b) {
  if ((a != null) != (b != null)) {
    return false;
  }

  if (a.runtimeType != b.runtimeType) {
    return false;
  }

  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      if (!eq(a[i], b[i])) {
        return false;
      }
    }
  } else if (a is Map && b is Map) {
    if (a.length != b.length) {
      return false;
    }

    for (final dynamic key in a.keys) {
      if (!b.containsKey(key) || !eq(b[key], a[key])) {
        return false;
      }
    }
  } else if (a != b) {
    return false;
  }

  return true;
}

Map<String, dynamic> flatMap(Map<String, dynamic> m) => m.flattened();

class JsonPatch {
  JsonPatchType type = JsonPatchType.deleted;
  dynamic value;
  dynamic to;

  @override
  String toString() =>
      "<${type.name}> ${type != JsonPatchType.deleted ? type == JsonPatchType.added ? value : "$value => $to" : ""}";

  void reverse() {
    switch (type) {
      case JsonPatchType.deleted:
        type = JsonPatchType.added;
        break;
      case JsonPatchType.changed:
        dynamic t = value;
        value = to;
        to = t;
        break;
      case JsonPatchType.added:
        type = JsonPatchType.deleted;
        break;
    }
  }

  static JsonPatch deleted(dynamic value) =>
      JsonPatch()..type = JsonPatchType.deleted;

  static JsonPatch changedTo(dynamic value, dynamic to) => JsonPatch()
    ..value = value
    ..to = to
    ..type = JsonPatchType.changed;

  static JsonPatch added(dynamic value) => JsonPatch()
    ..value = value
    ..type = JsonPatchType.added;
}

enum JsonPatchType { deleted, changed, added }

extension XMap on Map<String, dynamic> {
  Map<String, dynamic> copy() {
    Map<String, dynamic> f = <String, dynamic>{};
    forEach((key, value) => f[key] = value);
    return f;
  }

  Map<String, dynamic> inversePatched(Map<String, JsonPatch> patch,
      {bool forceMerge = false}) {
    Map<String, dynamic> self = flattened();
    patch.forEach((key, value) {
      switch (value.type) {
        case JsonPatchType.added:
          if (forceMerge || self.containsKey(key)) {
            self.remove(key);
          }
          break;
        case JsonPatchType.changed:
          if (forceMerge || value.to == self[key]) {
            self[key] = value.value;
          }
          break;
        case JsonPatchType.deleted:
          if (forceMerge || !self.containsKey(key)) {
            self[key] = value.value;
          }
          break;
      }
    });

    return self.expanded();
  }

  Map<String, dynamic> patched(Map<String, JsonPatch> patch,
      {bool forceMerge = false}) {
    Map<String, dynamic> self = flattened();
    patch.forEach((key, value) {
      switch (value.type) {
        case JsonPatchType.deleted:
          if (forceMerge || self.containsKey(key)) {
            self.remove(key);
          }
          break;
        case JsonPatchType.changed:
          if (forceMerge || value.value == self[key]) {
            self[key] = value.to;
          }
          break;
        case JsonPatchType.added:
          if (forceMerge || !self.containsKey(key)) {
            self[key] = value.value;
          }
          break;
      }
    });

    return self.expanded();
  }

  Map<String, JsonPatch> diff(Map<String, dynamic> altered) {
    Map<String, JsonPatch> patch = <String, JsonPatch>{};
    Map<String, dynamic> self = flattened();
    Map<String, dynamic> alt = altered.flattened();
    alt.forEach((key, value) {
      if (!self.containsKey(key)) {
        patch[key] = JsonPatch.added(value);
      } else if (!eq(self[key], value)) {
        patch[key] = JsonPatch.changedTo(self[key], value);
      }
    });
    self.forEach((key, value) {
      if (!alt.containsKey(key)) {
        patch[key] = JsonPatch.deleted(value);
      }
    });

    return patch;
  }

  Map<String, dynamic> expanded() {
    Map<String, dynamic> expanded = <String, dynamic>{};
    forEach((key, value) => expanded.putFlatKey(key, value));
    return expanded;
  }

  Map<String, dynamic> flattened({String prefix = ""}) {
    Map<String, dynamic> flat = <String, dynamic>{};

    forEach((key, value) {
      if (value is Map<String, dynamic>) {
        value
            .flattened(prefix: "$prefix$key.")
            .forEach((key, value) => flat[key] = value);
      } else {
        flat["$prefix$key"] = value;
      }
    });

    return flat;
  }

  void putFlatKey(String key, dynamic value) {
    if (key.contains(".")) {
      Map<String, dynamic> cursor = this;
      List<String> segments = key.split(".");

      for (int i = 0; i < segments.length - 1; i++) {
        cursor.putIfAbsent(segments[i], () => <String, dynamic>{});
        cursor = cursor[segments[i]];
      }

      cursor[segments.last] = value;
    } else {
      this[key] = value;
    }
  }

  Map<String, dynamic> insertHierarchical(Map<String, dynamic> onto) {
    Map<String, dynamic> mix = <String, dynamic>{};
    flattened().forEach((key, value) => mix[key] = value);
    onto.flattened().forEach((key, value) => mix[key] = value);
    return mix.expanded();
  }
}
