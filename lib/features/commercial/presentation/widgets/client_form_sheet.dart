import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/shared/widget/buttons/app_button.dart';
import '../../../../core/shared/widget/forms/app_form_section.dart';
import '../../../../core/shared/widget/forms/app_text_field.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../localization/ui_translations.dart';
import '../../data/models/models.dart';
import '../controllers/commercial_map_controller.dart';
import 'brand_selection_widget.dart';

/// The create/update client form.
///
/// Replaces a ~630-line `_buildClientFormOverlay` method that was a single
/// flat `Column` nested up to 20 levels deep. Three things were wrong with it
/// beyond the nesting:
///
/// 1. **No structure.** Twenty controls in one run, with identity, contact,
///    commercial and location inputs interleaved and nothing marking the
///    boundaries (WCAG 2.1 AA §1.3.1). They are now five labelled
///    [AppFormSection]s.
///
/// 2. **The submit button was at the bottom of a 700px scroll.** On a phone
///    that meant scrolling the entire form to reach it, every time. The action
///    is now pinned to the footer and always reachable.
///
/// 3. **The whole dialog scrolled, title included.** Users lost track of what
///    they were filling in. The header is pinned too.
///
/// The field styling itself moved into [AppTextField], which is why this file
/// is a list of fields rather than a wall of `InputDecoration`.
class ClientFormSheet extends StatelessWidget {
  const ClientFormSheet({
    super.key,
    required this.controller,
    required this.onPickParentClients,
  });

  final CommercialMapController controller;

  /// Opens the parent-client picker. Owned by the page because it is presented
  /// as a bottom sheet over the page, not over this form.
  final VoidCallback onPickParentClients;

  String _tr(String key) => UiTranslations.t(key);

  bool get _isB2B => controller.registrationType.value == 'b2b';
  bool get _isSubClient => controller.registrationType.value == 'sub_client';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      color: AppPalette.scrim,
      child: Center(
        child: Padding(
          // Follows the keyboard so the focused field is never hidden behind
          // it — the old layout had no inset handling at all.
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: AppSpacing.md + media.viewInsets.bottom,
          ),
          child: ConstraintsBox(
            child: Material(
              color: AppPalette.surface,
              borderRadius: AppRadius.lgAll,
              clipBehavior: Clip.antiAlias,
              child: Form(
                key: controller.clientFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Header(
                      title: Obx(
                        () => Text(
                          _isSubClient ? _tr('subClient') : _tr('newClientB2B'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                      ),
                      closeLabel: _tr('close'),
                      onClose: controller.closeClientForm,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Obx(() => _identitySection()),
                            const SizedBox(height: AppSpacing.xl),
                            Obx(() => _contactSection()),
                            const SizedBox(height: AppSpacing.xl),
                            Obx(() => _commercialSection()),
                            const SizedBox(height: AppSpacing.xl),
                            _notesSection(),
                            const SizedBox(height: AppSpacing.xl),
                            _locationSection(),
                          ],
                        ),
                      ),
                    ),
                    _Footer(controller: controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Sections ----------------------------------------------------------

  Widget _identitySection() {
    return AppFormSection(
      title: _tr('sectionIdentity'),
      icon: Icons.badge_outlined,
      children: [
        if (_isB2B) ...[
          AppTextField(
            controller: controller.codeClientController,
            label: _tr('codeClient'),
            icon: Icons.tag,
            textInputAction: TextInputAction.next,
            enabled: controller.isFieldEditableForCommercialUpdate(
              'codeClient',
            ),
          ),
          AppTextField(
            controller: controller.raisonSocialeController,
            label: _tr('raisonSociale'),
            icon: Icons.business_outlined,
            textInputAction: TextInputAction.next,
            enabled: controller.isFieldEditableForCommercialUpdate(
              'raisonSociale',
            ),
          ),
          AppTextField(
            controller: controller.matriculeFiscalController,
            label: _tr('matriculeFiscal'),
            icon: Icons.receipt_long_outlined,
            textInputAction: TextInputAction.next,
            enabled: controller.isFieldEditableForCommercialUpdate(
              'matriculeFiscal',
            ),
          ),
        ],
        if (_isSubClient) ...[
          AppTextField(
            controller: controller.nomController,
            label: _tr('lastName'),
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: controller.prenomController,
            label: _tr('firstName'),
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: controller.nomAgenceController,
            label: _tr('agency'),
            icon: Icons.store_outlined,
            textInputAction: TextInputAction.next,
          ),
        ],
      ],
    );
  }

  Widget _contactSection() {
    return AppFormSection(
      title: _tr('sectionContact'),
      icon: Icons.contact_phone_outlined,
      children: [
        AppTextField(
          controller: controller.telephoneController,
          label: _tr('phone'),
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        if (_isB2B)
          AppTextField(
            controller: controller.emailController,
            label: _tr('email'),
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
      ],
    );
  }

  Widget _commercialSection() {
    final showParents = _isSubClient && !controller.isProspectFormMode.value;
    final showBrands = _isB2B || _isSubClient;

    if (!showParents && !showBrands) return const SizedBox.shrink();

    return AppFormSection(
      title: _tr('sectionCommercial'),
      icon: Icons.handshake_outlined,
      children: [
        if (showParents) _parentClientsGroup(),
        if (showBrands) _brandsGroup(),
      ],
    );
  }

  Widget _parentClientsGroup() {
    return AppFieldGroup(
      label: _tr('parentClients'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() {
            final selected = controller.getSelectedParentClients();
            if (selected.isEmpty) {
              return Text(
                _tr('noneSelectedProspectHint'),
                style: const TextStyle(
                  fontSize: AppA11y.minFontSize,
                  color: AppPalette.textTertiary,
                ),
              );
            }
            return Wrap(
              spacing: AppSpacing.xxs + 2,
              runSpacing: AppSpacing.xxs + 2,
              children: selected.map((parent) {
                final id = parent['id']?.toString() ?? '';
                final name = controller.getClientDisplayName(parent);
                return _RemovableChip(
                  label: name,
                  onRemove: () => controller.toggleParentClientSelection(id),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: _tr('selectParentClients'),
            icon: Icons.group_add_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onPickParentClients,
          ),
        ],
      ),
    );
  }

  Widget _brandsGroup() {
    final canEdit = _isSubClient || controller.canEditBrandsForCurrentClient;

    return AppFieldGroup(
      label: _tr('carBrands'),
      trailing: Obx(
        () => AppCountBadge(
          count: controller.selectedBrands.length,
          semanticsLabel: _tr('carBrands'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() {
            if (controller.selectedBrands.isEmpty) {
              return Text(
                _tr('noBrandSelected'),
                style: const TextStyle(
                  fontSize: AppA11y.minFontSize,
                  color: AppPalette.textTertiary,
                ),
              );
            }
            return Wrap(
              spacing: AppSpacing.xxs + 2,
              runSpacing: AppSpacing.xxs + 2,
              children: controller.selectedBrands
                  .map(
                    (brand) => _RemovableChip(
                      label: brand.displayName,
                      onRemove: () => controller.toggleBrand(brand),
                    ),
                  )
                  .toList(),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: _tr('selectBrands'),
            icon: Icons.directions_car_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: canEdit ? _openBrandPicker : null,
          ),
        ],
      ),
    );
  }

  Widget _notesSection() {
    return AppFormSection(
      title: _tr('sectionNotesPhoto'),
      icon: Icons.edit_note_outlined,
      children: [
        AppTextField(
          controller: controller.noteController,
          label: _tr('note'),
          icon: Icons.note_alt_outlined,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
        ),
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: _tr('takePhoto'),
                      icon: Icons.camera_alt_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: controller.isPickingImage.value
                          ? null
                          : controller.pickImageFromCamera,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: AppButton(
                      label: _tr('gallery'),
                      icon: Icons.photo_library_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: controller.isPickingImage.value
                          ? null
                          : controller.pickImageFromGallery,
                    ),
                  ),
                ],
              ),
              if (controller.selectedImageBytes.value != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _PhotoPreview(
                  bytes: controller.selectedImageBytes.value!,
                  onRemove: controller.removeSelectedImage,
                  removeLabel: _tr('close'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _locationSection() {
    return AppFormSection(
      title: _tr('sectionLocation'),
      icon: Icons.place_outlined,
      children: [
        AppButton(
          label: _tr('chooseLocationOnMap'),
          icon: Icons.map_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: controller.pickLocationFromMap,
        ),
        Obx(() {
          final location = controller.selectedLocation.value;
          final hasLocation = location != null;
          final text = hasLocation
              ? '${location.latitude.toStringAsFixed(6)}, '
                    '${location.longitude.toStringAsFixed(6)}'
              : _tr('touchMapBoutique');

          return Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: hasLocation
                  ? AppPalette.brandSurface
                  : AppPalette.surfaceMuted,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: hasLocation
                    ? AppPalette.brandInk.withValues(alpha: 0.3)
                    : AppPalette.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasLocation ? Icons.location_on : Icons.location_searching,
                  size: 18,
                  color: hasLocation
                      ? AppPalette.brandInk
                      : AppPalette.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      // Coordinates are data, so they get the stronger ink;
                      // the placeholder hint stays secondary.
                      color: hasLocation
                          ? AppPalette.textPrimary
                          : AppPalette.textSecondary,
                      fontWeight: hasLocation
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _openBrandPicker() {
    Get.bottomSheet<void>(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: AppRadius.lgAll,
            ),
            child: Stack(
              children: [
                BrandSelectionWidget(
                  initialBrands: CarBrandsModel(
                    selectedBrands: controller.selectedBrands,
                  ),
                  onBrandsChanged: (brands) {
                    controller.selectedBrands
                      ..clear()
                      ..addAll(brands.selectedBrands);
                  },
                  isEditing: true,
                ),
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: _CloseButton(
                    label: _tr('close'),
                    onPressed: Get.back<void>,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

/// Caps the dialog so it does not stretch edge to edge on a tablet and never
/// grows taller than the viewport. The old overlay had neither limit.
class ConstraintsBox extends StatelessWidget {
  const ConstraintsBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: child,
    );
  }
}

/// Pinned dialog header.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onClose,
    required this.closeLabel,
  });

  final Widget title;
  final VoidCallback onClose;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: title)),
          _CloseButton(label: closeLabel, onPressed: onClose),
        ],
      ),
    );
  }
}

/// Pinned footer holding the single submit action.
class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final CommercialMapController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppPalette.surfaceMuted,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: Obx(() {
        final isUpdate = controller.selectedClientForUpdate.value != null;
        return AppButton(
          label: isUpdate
              ? controller.clientLocationActionLabel
              : UiTranslations.t('createClient'),
          isLoading: controller.isCreatingClient.value,
          onPressed: controller.submitClientForm,
        );
      }),
    );
  }
}

/// 48dp icon-only close control with a real accessible name.
///
/// The previous `IconButton(icon: Icon(Icons.close))` had no label, so screen
/// readers announced an unnamed button (WCAG §4.1.2).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: const SizedBox(
              width: AppA11y.minTouchTarget,
              height: AppA11y.minTouchTarget,
              child: Icon(
                Icons.close,
                size: 20,
                color: AppPalette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A selection chip with a remove affordance.
///
/// Material's bare [Chip] delete icon is 18dp inside an 18dp box — well under
/// the 48dp target minimum. This gives the remove action a real hit area.
class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.brandSurface,
        borderRadius: AppRadius.smAll,
      ),
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppPalette.brandInk,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: label,
            child: ExcludeSemantics(
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onRemove,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.close,
                      size: 15,
                      color: AppPalette.brandInk,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.bytes,
    required this.onRemove,
    required this.removeLabel,
  });

  final Uint8List bytes;
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: AppSpacing.xxs,
            top: AppSpacing.xxs,
            child: Semantics(
              button: true,
              label: removeLabel,
              child: ExcludeSemantics(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onRemove,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
