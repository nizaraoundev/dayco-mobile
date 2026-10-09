import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../localization/ui_translations.dart';
import '../controllers/commercial_map_controller.dart';
import '../pages/commercial_stock_page.dart';

/// The commercial map's navigation drawer.
///
/// Extracted from `commercial_map_page.dart`, where it was a 200-line method
/// in the middle of a 2,100-line file.
///
/// The old layout was a flat `ListView` of cards: profile card, details card,
/// three action tiles, a switch, two language buttons and a logout tile, each
/// with its own shadow and its own ad-hoc gap (14, 2, 16, 4, 12 px). Nothing
/// signalled which items belonged together, so the sidebar read as ten
/// unrelated boxes.
///
/// It is now three labelled groups — identity, actions, preferences — with one
/// shared gap and a single destructive action pinned at the bottom, out of the
/// path of the things people tap every day.
class CommercialDrawer extends StatelessWidget {
  const CommercialDrawer({
    super.key,
    required this.controller,
    required this.onOpenSubClients,
  });

  final CommercialMapController controller;

  /// Opens the sub-clients sheet. Passed in rather than called on the
  /// controller because the sheet is built from page-level widgets; the
  /// drawer should not have to know how it is presented.
  final VoidCallback onOpenSubClients;

  String _tr(String key) => UiTranslations.t(key);

  @override
  Widget build(BuildContext context) {
    // Deliberately no `Obx` at this level. Each observable is read inside the
    // child that displays it, so the rebuild scope stays as narrow as the
    // value it depends on. Wrapping the whole drawer instead would also throw
    // "improper use of a GetX" — an outer Obx that reads no observable in its
    // own builder is an error, and after these rows moved into their own
    // widgets, none of the reads happen in this scope any more.
    return Drawer(
      backgroundColor: AppPalette.surfaceMuted,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                children: [
                  _IdentityCard(controller: controller),
                  const SizedBox(height: AppSpacing.lg),
                  _DrawerGroup(
                    label: _tr('actions'),
                    children: [
                      _DrawerTile(
                        icon: Icons.add_business_outlined,
                        title: _tr('newClientB2B'),
                        subtitle: _tr('createNewClient'),
                        onTap: () {
                          Get.back<void>();
                          controller.openClientForm();
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.person_add_alt_outlined,
                        title: _tr('subClientsProspects'),
                        subtitle: _tr('manageSubClientsProspects'),
                        onTap: () {
                          Get.back<void>();
                          onOpenSubClients();
                        },
                      ),
                      _DrawerTile(
                        icon: Icons.inventory_2_outlined,
                        title: _tr('stocks'),
                        subtitle: _tr('stocksSubtitle'),
                        onTap: () {
                          Get.back<void>();
                          Get.to<void>(() => const CommercialStockPage());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DrawerGroup(
                    label: _tr('preferences'),
                    children: [
                      _MapTypeToggle(controller: controller),
                      const Divider(height: 1, color: AppPalette.border),
                      _LanguageSelector(controller: controller),
                    ],
                  ),
                ],
              ),
            ),
            // Logout sits outside the scroll area so a destructive action is
            // never adjacent to the everyday ones, and never scrolls under a
            // thumb reaching for "Stocks".
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: _LogoutButton(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile summary. Replaces the old two-card stack (avatar card + a second
/// card of `_profileRow` label/value pairs) with one card, because they were
/// always shown together and described the same person.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.controller});

  final CommercialMapController controller;

  String _tr(String key) => UiTranslations.t(key);

  String get _displayName {
    final name = controller.profileData['name'];
    if (name != null && name.isNotEmpty) return name;
    final composed =
        '${controller.profileData['nom'] ?? ''} ${controller.profileData['prenom'] ?? ''}'
            .trim();
    return composed.isEmpty ? _tr('noData') : composed;
  }

  @override
  Widget build(BuildContext context) {
    // Obx lives here, where profileData/profileRoles/profileRegions are
    // actually read, so only this card rebuilds when the profile loads.
    return Obx(_buildCard);
  }

  Widget _buildCard() {
    final email = controller.profileData['email'];
    final phone = controller.profileData['telephone'];
    final roles = controller.profileRoles;
    final regions = controller.profileRegions;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppElevation.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppPalette.brandSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppPalette.brandInk,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: AppA11y.minFontSize,
                          // textTertiary is the AA-safe grey; the old
                          // Colors.black54 at 12px was borderline.
                          color: AppPalette.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (phone != null && phone.isNotEmpty ||
              roles.isNotEmpty ||
              regions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppPalette.border),
            const SizedBox(height: AppSpacing.xs),
            if (phone != null && phone.isNotEmpty)
              _MetaRow(icon: Icons.phone_outlined, value: phone),
            if (roles.isNotEmpty)
              _MetaRow(
                icon: Icons.badge_outlined,
                value: roles.join(', '),
                semanticPrefix: _tr('roles'),
              ),
            if (regions.isNotEmpty)
              _MetaRow(
                icon: Icons.map_outlined,
                value: regions.join(', '),
                semanticPrefix: _tr('regions'),
              ),
          ],
        ],
      ),
    );
  }
}

/// Icon + value line. The icon is decorative; [semanticPrefix] supplies the
/// meaning a sighted user reads from the icon shape.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.value,
    this.semanticPrefix,
  });

  final IconData icon;
  final String value;
  final String? semanticPrefix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticPrefix == null ? value : '$semanticPrefix: $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: AppPalette.textTertiary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled group of drawer rows sharing one card.
///
/// One card per group instead of one card per row: it is the grouping that
/// carries the meaning, and it removes nine redundant shadows from the sidebar.
class _DrawerGroup extends StatelessWidget {
  const _DrawerGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xxs,
            bottom: AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppPalette.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: AppRadius.mdAll,
            boxShadow: AppElevation.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      // Guarantees the row clears 48dp even when there is no subtitle.
      minVerticalPadding: AppSpacing.sm,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppPalette.brandSurface,
          borderRadius: AppRadius.smAll,
        ),
        // Decorative: the title already names the action.
        child: ExcludeSemantics(
          child: Icon(icon, color: AppPalette.brandInk, size: 20),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppPalette.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: AppA11y.minFontSize,
                color: AppPalette.textTertiary,
              ),
            ),
      trailing: const ExcludeSemantics(
        child: Icon(
          Icons.chevron_right,
          size: 20,
          color: AppPalette.textTertiary,
        ),
      ),
    );
  }
}

/// Satellite/standard map toggle.
///
/// Previously a `SwitchListTile` whose subtitle was the only thing stating the
/// current mode. The switch now carries its own state semantically, so screen
/// readers announce "Hybrid map, switch, on" rather than reading a subtitle
/// that happens to say so.
class _MapTypeToggle extends StatelessWidget {
  const _MapTypeToggle({required this.controller});

  final CommercialMapController controller;

  String _tr(String key) => UiTranslations.t(key);

  @override
  Widget build(BuildContext context) => Obx(_buildTile);

  Widget _buildTile() {
    final isHybrid = controller.selectedMapType.value == MapType.hybrid;

    return SwitchListTile(
      value: isHybrid,
      onChanged: (value) =>
          controller.setMapType(value ? MapType.hybrid : MapType.normal),
      activeThumbColor: AppPalette.brandStrong,
      minVerticalPadding: AppSpacing.sm,
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppPalette.brandSurface,
          borderRadius: AppRadius.smAll,
        ),
        child: const ExcludeSemantics(
          child: Icon(
            Icons.layers_outlined,
            color: AppPalette.brandInk,
            size: 20,
          ),
        ),
      ),
      title: Text(
        _tr('hybridMap'),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppPalette.textPrimary,
        ),
      ),
      subtitle: Text(
        isHybrid ? _tr('hybridOn') : _tr('hybridOffNormal'),
        style: const TextStyle(
          fontSize: AppA11y.minFontSize,
          color: AppPalette.textTertiary,
        ),
      ),
    );
  }
}

/// Language picker as a segmented control.
///
/// Was two equal `OutlinedButton`s showing "🇫🇷 FR" and "🇹🇳 AR" with no
/// indication of which was active — the current language was invisible, and
/// the flag emoji was the only cue, which screen readers read as a country
/// name. Now the active option is marked by fill *and* a check icon (so the
/// state does not rest on colour alone, §1.4.1) and is announced as selected.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.controller});

  final CommercialMapController controller;

  String _tr(String key) => UiTranslations.t(key);

  @override
  Widget build(BuildContext context) => Obx(_buildSelector);

  Widget _buildSelector() {
    final current = controller.currentLanguageCode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('language'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _LanguageOption(
                  code: 'fr',
                  label: 'Français',
                  isSelected: current == 'fr',
                  onTap: () => controller.changeLanguage('fr'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _LanguageOption(
                  code: 'ar',
                  label: 'العربية',
                  isSelected: current == 'ar',
                  onTap: () => controller.changeLanguage('ar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: isSelected ? AppPalette.brandSurface : AppPalette.surfaceMuted,
          borderRadius: AppRadius.smAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.smAll,
            child: Container(
              height: AppA11y.minTouchTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: AppRadius.smAll,
                border: Border.all(
                  color: isSelected ? AppPalette.brandInk : AppPalette.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: AppPalette.brandInk,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppPalette.brandInk
                            : AppPalette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.controller});

  final CommercialMapController controller;

  String _tr(String key) => UiTranslations.t(key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _tr('logout'),
      child: ExcludeSemantics(
        child: Material(
          color: AppPalette.surface,
          borderRadius: AppRadius.mdAll,
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () async {
              Get.back<void>();
              await controller.logout();
            },
            child: Container(
              height: AppA11y.minTouchTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: AppPalette.danger.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.logout, size: 18, color: AppPalette.danger),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _tr('logout'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
