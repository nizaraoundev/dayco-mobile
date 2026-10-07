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

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {'selectedBrands': selectedBrands.map((b) => b.index).toList()};
  }

  /// Create from JSON
  factory CarBrandsModel.fromJson(Map<String, dynamic> json) {
    final brandIndices = List<int>.from(json['selectedBrands'] ?? []);
    final brands = brandIndices.map((index) => CarBrand.values[index]).toList();
    return CarBrandsModel(selectedBrands: brands);
  }

  /// Copy with modifications
  CarBrandsModel copyWith({List<CarBrand>? selectedBrands}) {
    return CarBrandsModel(
      selectedBrands: selectedBrands ?? this.selectedBrands,
    );
  }
}
