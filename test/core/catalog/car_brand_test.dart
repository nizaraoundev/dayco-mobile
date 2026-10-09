import 'package:dayco_mobile/core/catalog/car_brand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CarBrandCodec', () {
    test('encodes to the display name the backend stores', () {
      expect(CarBrandCodec.encode(CarBrand.mercedBenz), 'Mercedes-Benz');
      expect(CarBrandCodec.encode(CarBrand.peugeot), 'Peugeot');
    });

    test('parses the display name form', () {
      expect(CarBrandCodec.tryParse('Mercedes-Benz'), CarBrand.mercedBenz);
      expect(CarBrandCodec.tryParse('Citroën'), CarBrand.citroen);
    });

    test('parses the legacy enum-name form written on sub-client create', () {
      // The old create path sent `brand.name`, so records exist with this shape.
      expect(CarBrandCodec.tryParse('mercedBenz'), CarBrand.mercedBenz);
      expect(CarBrandCodec.tryParse('alfaRomeo'), CarBrand.alfaRomeo);
    });

    test('is insensitive to case, accents and punctuation', () {
      expect(CarBrandCodec.tryParse('mercedes benz'), CarBrand.mercedBenz);
      expect(CarBrandCodec.tryParse('MERCEDES-BENZ'), CarBrand.mercedBenz);
      expect(CarBrandCodec.tryParse('citroen'), CarBrand.citroen);
      expect(CarBrandCodec.tryParse('CITROËN'), CarBrand.citroen);
    });

    test('returns null for an unknown or blank brand', () {
      expect(CarBrandCodec.tryParse('Tesla'), isNull);
      expect(CarBrandCodec.tryParse(''), isNull);
      expect(CarBrandCodec.tryParse('   '), isNull);
    });

    test('round-trips every brand in the catalog', () {
      for (final brand in CarBrand.values) {
        expect(
          CarBrandCodec.tryParse(CarBrandCodec.encode(brand)),
          brand,
          reason: 'display name of ${brand.name} must parse back to itself',
        );
        expect(
          CarBrandCodec.tryParse(brand.name),
          brand,
          reason: 'enum name of ${brand.name} must parse back to itself',
        );
      }
    });

    test('parseAll skips unrecognised entries instead of failing', () {
      expect(CarBrandCodec.parseAll(['Peugeot', 'Tesla', null, 'kia']), [
        CarBrand.peugeot,
        CarBrand.kia,
      ]);
    });
  });

  group('CarBrandsModel serialisation', () {
    test('persists stable names, not indices', () {
      final model = CarBrandsModel(
        selectedBrands: [CarBrand.peugeot, CarBrand.kia],
      );
      expect(model.toJson(), {
        'selectedBrands': ['peugeot', 'kia'],
      });
    });

    test('round-trips through JSON', () {
      final original = CarBrandsModel(
        selectedBrands: [CarBrand.mercedBenz, CarBrand.fiat],
      );
      final restored = CarBrandsModel.fromJson(original.toJson());
      expect(restored.selectedBrands, original.selectedBrands);
    });

    test('still reads the legacy index form', () {
      final restored = CarBrandsModel.fromJson({
        'selectedBrands': [CarBrand.peugeot.index, CarBrand.kia.index],
      });
      expect(restored.selectedBrands, [CarBrand.peugeot, CarBrand.kia]);
    });

    test('skips an out-of-range legacy index instead of throwing', () {
      // `CarBrand.values[index]` used to raise RangeError here and take the
      // whole client payload down with it.
      final restored = CarBrandsModel.fromJson({
        'selectedBrands': [0, 9999, -1],
      });
      expect(restored.selectedBrands, [CarBrand.values.first]);
    });

    test('tolerates a malformed payload', () {
      expect(CarBrandsModel.fromJson({}).selectedBrands, isEmpty);
      expect(
        CarBrandsModel.fromJson({'selectedBrands': 'peugeot'}).selectedBrands,
        isEmpty,
      );
    });

    test('copyWith does not alias the original list', () {
      final original = CarBrandsModel(selectedBrands: [CarBrand.peugeot]);
      final copy = original.copyWith();

      copy.toggleBrand(CarBrand.kia);

      expect(original.selectedBrands, [CarBrand.peugeot]);
      expect(copy.selectedBrands, [CarBrand.peugeot, CarBrand.kia]);
    });
  });
}
