/// Car brands organized by country
enum CarBrand {
  // French Brands
  peugeot,
  citroen,
  ds,
  renault,
  dacia,

  // German Brands
  mercedBenz,
  bmw,
  audi,
  volkswagen,
  porsche,
  opel,

  // Japanese Brands
  toyota,
  suzuki,
  nissan,
  mitsubishi,
  mazda,
  honda,
  subaru,

  // Korean Brands
  hyundai,
  kia,

  // Italian Brands
  fiat,
  alfaRomeo,
  jeep,

  // Spanish Brands
  seat,

  // Chinese Brands
  chery,
  geely,
  baic,
  dfsk,
  mg,
  greatWall,
  haval,
  dongfeng,

  // American Brands
  ford,
  chevrolet,

  // British Brands
  landRover,
  jaguar,
  mini,
}

/// Extension to get brand details
extension CarBrandExtension on CarBrand {
  /// Get the display name of the brand
  String get displayName {
    switch (this) {
      // French
      case CarBrand.peugeot:
        return 'Peugeot';
      case CarBrand.citroen:
        return 'Citroën';
      case CarBrand.ds:
        return 'DS Automobiles';
      case CarBrand.renault:
        return 'Renault';
      case CarBrand.dacia:
        return 'Dacia';

      // German
      case CarBrand.mercedBenz:
        return 'Mercedes-Benz';
      case CarBrand.bmw:
        return 'BMW';
      case CarBrand.audi:
        return 'Audi';
      case CarBrand.volkswagen:
        return 'Volkswagen';
      case CarBrand.porsche:
        return 'Porsche';
      case CarBrand.opel:
        return 'Opel';

      // Japanese
      case CarBrand.toyota:
        return 'Toyota';
      case CarBrand.suzuki:
        return 'Suzuki';
      case CarBrand.nissan:
        return 'Nissan';
      case CarBrand.mitsubishi:
        return 'Mitsubishi';
      case CarBrand.mazda:
        return 'Mazda';
      case CarBrand.honda:
        return 'Honda';
      case CarBrand.subaru:
        return 'Subaru';

      // Korean
      case CarBrand.hyundai:
        return 'Hyundai';
      case CarBrand.kia:
        return 'Kia';

      // Italian
      case CarBrand.fiat:
        return 'Fiat';
      case CarBrand.alfaRomeo:
        return 'Alfa Romeo';
      case CarBrand.jeep:
        return 'Jeep';

      // Spanish
      case CarBrand.seat:
        return 'SEAT';

      // Chinese
      case CarBrand.chery:
        return 'Chery';
      case CarBrand.geely:
        return 'Geely';
      case CarBrand.baic:
        return 'BAIC';
      case CarBrand.dfsk:
        return 'DFSK';
      case CarBrand.mg:
        return 'MG';
      case CarBrand.greatWall:
        return 'Great Wall';
      case CarBrand.haval:
        return 'Haval';
      case CarBrand.dongfeng:
        return 'Dongfeng';

      // American
      case CarBrand.ford:
        return 'Ford';
      case CarBrand.chevrolet:
        return 'Chevrolet';

      // British
      case CarBrand.landRover:
        return 'Land Rover';
      case CarBrand.jaguar:
        return 'Jaguar';
      case CarBrand.mini:
        return 'MINI';
    }
  }

  /// Get the country/region of the brand
  String get country {
    switch (this) {
      case CarBrand.peugeot:
      case CarBrand.citroen:
      case CarBrand.ds:
      case CarBrand.renault:
      case CarBrand.dacia:
        return '🇫🇷 French';

      case CarBrand.mercedBenz:
      case CarBrand.bmw:
      case CarBrand.audi:
      case CarBrand.volkswagen:
      case CarBrand.porsche:
      case CarBrand.opel:
        return '🇩🇪 German';

      case CarBrand.toyota:
      case CarBrand.suzuki:
      case CarBrand.nissan:
      case CarBrand.mitsubishi:
      case CarBrand.mazda:
      case CarBrand.honda:
      case CarBrand.subaru:
        return '🇯🇵 Japanese';

      case CarBrand.hyundai:
      case CarBrand.kia:
        return '🇰🇷 Korean';

      case CarBrand.fiat:
      case CarBrand.alfaRomeo:
      case CarBrand.jeep:
        return '🇮🇹 Italian';

      case CarBrand.seat:
        return '🇪🇸 Spanish';

      case CarBrand.chery:
      case CarBrand.geely:
      case CarBrand.baic:
      case CarBrand.dfsk:
      case CarBrand.mg:
      case CarBrand.greatWall:
      case CarBrand.haval:
      case CarBrand.dongfeng:
        return '🇨🇳 Chinese';

      case CarBrand.ford:
      case CarBrand.chevrolet:
        return '🇺🇸 American';

      case CarBrand.landRover:
      case CarBrand.jaguar:
      case CarBrand.mini:
        return '🇬🇧 British';
    }
  }
}

/// Car brands model for storing available brands in boutique
class CarBrandsModel {
  final List<CarBrand> selectedBrands;

  CarBrandsModel({required this.selectedBrands});

  /// Get all brands grouped by country
  static Map<String, List<CarBrand>> getBrandsByCountry() {
    final Map<String, List<CarBrand>> grouped = {};

    for (final brand in CarBrand.values) {
      final country = brand.country;
      if (!grouped.containsKey(country)) {
        grouped[country] = [];
      }
      grouped[country]!.add(brand);
    }

    return grouped;
  }

  /// Get selected brands grouped by country
  Map<String, List<CarBrand>> getSelectedBrandsByCountry() {
    final Map<String, List<CarBrand>> grouped = {};

    for (final brand in selectedBrands) {
      final country = brand.country;
      if (!grouped.containsKey(country)) {
        grouped[country] = [];
      }
      grouped[country]!.add(brand);
    }

    return grouped;
  }

  /// Check if a brand is selected
  bool isBrandSelected(CarBrand brand) => selectedBrands.contains(brand);

  /// Toggle brand selection
  void toggleBrand(CarBrand brand) {
    if (selectedBrands.contains(brand)) {
      selectedBrands.remove(brand);
    } else {
      selectedBrands.add(brand);
    }
  }

  /// Get display list of selected brands
  List<String> getSelectedBrandNames() {
    return selectedBrands.map((brand) => brand.displayName).toList();
  }

  /// Convert to JSON for storage.
  ///
  /// Persists stable enum *names*, not indices. The previous implementation
  /// stored `brand.index`, so inserting or reordering a single entry in
  /// [CarBrand] silently remapped every brand already saved on a client.
  Map<String, dynamic> toJson() {
    return {'selectedBrands': selectedBrands.map((b) => b.name).toList()};
  }

  /// Create from JSON.
  ///
  /// Accepts the stable-name form written by [toJson] and the legacy
  /// index form, so data persisted by earlier builds still loads. Unknown
  /// entries are skipped rather than throwing — `CarBrand.values[index]` used
  /// to raise a `RangeError` and take the whole client payload down with it.
  factory CarBrandsModel.fromJson(Map<String, dynamic> json) {
    final raw = json['selectedBrands'];
    if (raw is! List) return CarBrandsModel(selectedBrands: []);

    final byName = {for (final brand in CarBrand.values) brand.name: brand};
    final brands = <CarBrand>[];

    for (final entry in raw) {
      if (entry is int) {
        // Legacy index form.
        if (entry >= 0 && entry < CarBrand.values.length) {
          brands.add(CarBrand.values[entry]);
        }
        continue;
      }

      final name = entry?.toString().trim();
      if (name == null || name.isEmpty) continue;

      final brand = byName[name] ?? CarBrandCodec.tryParse(name);
      if (brand != null) brands.add(brand);
    }

    return CarBrandsModel(selectedBrands: brands);
  }

  /// Copy with modifications.
  ///
  /// The list is copied. Previously the copy shared its backing list with the
  /// original, so [toggleBrand] on one instance mutated the other.
  CarBrandsModel copyWith({List<CarBrand>? selectedBrands}) {
    return CarBrandsModel(
      selectedBrands: List<CarBrand>.from(selectedBrands ?? this.selectedBrands),
    );
  }
}

/// Converts between [CarBrand] and the strings the backend stores in `marques`.
///
/// The original code wrote two different representations for the same field:
/// creating a sub-client sent `brand.name` (`"mercedBenz"`), while updating a
/// sub-client and creating a B2B client both sent `brand.displayName`
/// (`"Mercedes-Benz"`). Editing a client therefore rewrote its brands into a
/// different vocabulary than the one it was created with.
///
/// [encode] settles on `displayName` — the representation two of the three
/// original call sites already used — and [tryParse] accepts either, so records
/// written by older builds still resolve.
abstract final class CarBrandCodec {
  const CarBrandCodec._();

  /// The value to send to the backend for [brand].
  static String encode(CarBrand brand) => brand.displayName;

  /// The values to send for [brands].
  static List<String> encodeAll(Iterable<CarBrand> brands) =>
      brands.map(encode).toList(growable: false);

  /// Resolves a backend string to a [CarBrand], accepting both the display name
  /// and the enum name, case- and punctuation-insensitively.
  static CarBrand? tryParse(String value) {
    final needle = _normalise(value);
    if (needle.isEmpty) return null;

    for (final brand in CarBrand.values) {
      if (_normalise(brand.displayName) == needle) return brand;
      if (_normalise(brand.name) == needle) return brand;
    }
    return null;
  }

  /// Resolves a list of backend strings, skipping unrecognised entries.
  static List<CarBrand> parseAll(Iterable<dynamic> values) => values
      .map((value) => tryParse(value?.toString() ?? ''))
      .whereType<CarBrand>()
      .toList(growable: false);

  /// Strips case, accents, spaces and punctuation so `"Mercedes-Benz"`,
  /// `"mercedBenz"` and `"mercedes benz"` all compare equal.
  static String _normalise(String value) {
    const accents = 'àâäéèêëïîôöùûüçñ';
    const plain = 'aaaeeeeiioouuucn';

    final buffer = StringBuffer();
    for (final char in value.toLowerCase().split('')) {
      final accentIndex = accents.indexOf(char);
      if (accentIndex != -1) {
        buffer.write(plain[accentIndex]);
      } else if (RegExp(r'[a-z0-9]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
