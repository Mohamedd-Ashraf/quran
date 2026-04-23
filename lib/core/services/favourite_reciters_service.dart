import 'package:shared_preferences/shared_preferences.dart';

class FavouriteRecitersService {
  static const _key = 'favourite_reciters';

  final SharedPreferences _prefs;

  FavouriteRecitersService(this._prefs);

  List<String> getFavourites() {
    return _prefs.getStringList(_key) ?? [];
  }

  bool isFavourite(String identifier) {
    return getFavourites().contains(identifier);
  }

  Future<void> toggleFavourite(String identifier) async {
    final list = getFavourites().toList();
    if (list.contains(identifier)) {
      list.remove(identifier);
    } else {
      list.add(identifier);
    }
    await _prefs.setStringList(_key, list);
  }

  Future<void> addFavourite(String identifier) async {
    final list = getFavourites().toList();
    if (!list.contains(identifier)) {
      list.add(identifier);
      await _prefs.setStringList(_key, list);
    }
  }

  Future<void> removeFavourite(String identifier) async {
    final list = getFavourites().toList();
    if (list.contains(identifier)) {
      list.remove(identifier);
      await _prefs.setStringList(_key, list);
    }
  }
}
