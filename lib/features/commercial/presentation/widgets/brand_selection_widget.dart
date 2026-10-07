import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// Widget for selecting car brands for a client's boutique
class BrandSelectionWidget extends StatefulWidget {
  final CarBrandsModel initialBrands;
  final Function(CarBrandsModel) onBrandsChanged;
  final bool isEditing;

  const BrandSelectionWidget({
    super.key,
    required this.initialBrands,
    required this.onBrandsChanged,
    this.isEditing = false,
  });

  @override
  State<BrandSelectionWidget> createState() => _BrandSelectionWidgetState();
}

class _BrandSelectionWidgetState extends State<BrandSelectionWidget> {
  late CarBrandsModel _selectedBrands;

  @override
  void initState() {
    super.initState();
    _selectedBrands = CarBrandsModel(
      selectedBrands: List.from(widget.initialBrands.selectedBrands),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandsByCountry = CarBrandsModel.getBrandsByCountry();
    final selectedByCountry = _selectedBrands.getSelectedBrandsByCountry();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marques disponibles',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sélectionnez les marques que vous commercialisez',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                ...brandsByCountry.entries.map((entry) {
                  final country = entry.key;
                  final brands = entry.value;
                  final selectedCount = selectedByCountry[country]?.length ?? 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Country header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 16),
                        child: Row(
                          children: [
                            Text(
                              country,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ColorManager.primaryColor.withOpacity(
                                  0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$selectedCount/${brands.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorManager.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Brands grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: brands.map((brand) {
                          final isSelected = _selectedBrands.isBrandSelected(
                            brand,
                          );
                          return FilterChip(
                            label: Text(brand.displayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedBrands.toggleBrand(brand);
                              });
                              widget.onBrandsChanged(_selectedBrands);
                            },
                            backgroundColor: Colors.white,
                            selectedColor: ColorManager.primaryColor
                                .withOpacity(0.3),
                            side: BorderSide(
                              color: isSelected
                                  ? ColorManager.primaryColor
                                  : Colors.grey[300]!,
                            ),
                            checkmarkColor: ColorManager.primaryColor,
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (widget.isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back(result: _selectedBrands);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.primaryColor,
                      ),
                      child: const Text(
                        'Confirmer',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Display widget for showing selected brands (read-only)
class BrandDisplayWidget extends StatelessWidget {
  final CarBrandsModel brands;
  final VoidCallback onEdit;
  final bool isEditable;

  const BrandDisplayWidget({
    super.key,
    required this.brands,
    required this.onEdit,
    this.isEditable = false,
  });

  @override
  Widget build(BuildContext context) {
    final brandsByCountry = brands.getSelectedBrandsByCountry();

    if (brands.selectedBrands.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            'Aucune marque sélectionnée',
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...brandsByCountry.entries.map((entry) {
          final country = entry.key;
          final brands = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 12),
                child: Text(
                  country,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textSecondary,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: brands.map((brand) {
                  return Chip(
                    label: Text(
                      brand.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: ColorManager.primaryColor.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: ColorManager.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }
}
