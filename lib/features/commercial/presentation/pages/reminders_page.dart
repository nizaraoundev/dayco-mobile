import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/services/client_annotations_service.dart';
import '../controllers/commercial_map_controller.dart';
import '../../../../core/theme/dayco_colors.dart';
import '../../../../core/shared/widget/app_bar/dayco_app_bar.dart';

/// How far ahead the list looks.
enum _ReminderPeriod { all, week, month, overdue }

/// All reminders the commercial has set, newest due first.
///
/// Filters narrow by region, by client and by period. Only regions and
/// clients that actually have reminders are offered — listing every client
/// would be a long list of dead ends.
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final CommercialMapController controller =
      Get.find<CommercialMapController>();

  final Set<String> _regions = {};
  String? _clientId;
  _ReminderPeriod _period = _ReminderPeriod.all;
  bool _hideDone = true;

  List<ClientReminder> get _visible {
    final now = DateTime.now();
    final endOfWeek = now.add(Duration(days: 7 - now.weekday));
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final reminders = controller.clientReminders.where((reminder) {
      if (_hideDone && reminder.done) return false;

      if (_regions.isNotEmpty) {
        final region = reminder.region.isEmpty
            ? 'Sans région'
            : reminder.region;
        if (!_regions.contains(region)) return false;
      }

      if (_clientId != null && reminder.clientId != _clientId) return false;

      switch (_period) {
        case _ReminderPeriod.week:
          if (reminder.dueAt.isAfter(endOfWeek)) return false;
        case _ReminderPeriod.month:
          if (reminder.dueAt.isAfter(endOfMonth)) return false;
        case _ReminderPeriod.overdue:
          if (!reminder.isOverdue) return false;
        case _ReminderPeriod.all:
          break;
      }

      return true;
    }).toList();

    reminders.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return reminders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: DaycoAppBar(
        titleText: 'Rappels',
        elevation: 0,
      ),
      body: Obx(() {
        final reminders = _visible;

        return Column(
          children: [
            _buildFilters(),
            Expanded(
              child: reminders.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: reminders.length,
                      itemBuilder: (_, index) => _buildCard(reminders[index]),
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildFilters() {
    final regions = controller.reminderRegions;
    final clients = controller.reminderClients;

    return Container(
      color: context.dayco.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterLabel('Période'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _periodChip('Tous', _ReminderPeriod.all),
              _periodChip('Cette semaine', _ReminderPeriod.week),
              _periodChip('Ce mois', _ReminderPeriod.month),
              _periodChip('En retard', _ReminderPeriod.overdue),
            ],
          ),

          if (regions.length > 1) ...[
            const SizedBox(height: 14),
            _filterLabel('Régions'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: regions
                  .map(
                    (region) => _toggleChip(
                      label: region,
                      selected: _regions.contains(region),
                      onTap: () => setState(() {
                        _regions.contains(region)
                            ? _regions.remove(region)
                            : _regions.add(region);
                      }),
                    ),
                  )
                  .toList(),
            ),
          ],

          if (clients.isNotEmpty) ...[
            const SizedBox(height: 14),
            _filterLabel('Client'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _clientId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF1F3F6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              hint: const Text('Tous les clients'),
              items: [
                const DropdownMenuItem<String?>(
                  child: Text('Tous les clients'),
                ),
                ...clients.map(
                  (entry) => DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _clientId = value),
            ),
          ],

          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _hideDone = !_hideDone),
              icon: Icon(
                _hideDone ? Icons.visibility_off_outlined : Icons.check_circle,
                size: 17,
              ),
              label: Text(
                _hideDone ? 'Masquer les rappels faits' : 'Tout afficher',
                style: const TextStyle(fontSize: 12.5),
              ),
              style: TextButton.styleFrom(
                foregroundColor: ColorManager.textSecondary,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: ColorManager.primaryColor,
      ),
    );
  }

  Widget _periodChip(String label, _ReminderPeriod period) {
    return _toggleChip(
      label: label,
      selected: _period == period,
      onTap: () => setState(() => _period = period),
    );
  }

  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ColorManager.primaryColor : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ClientReminder reminder) {
    final overdue = reminder.isOverdue;
    final accent = reminder.done
        ? const Color(0xFF94A3B8)
        : (overdue ? const Color(0xFFDC2626) : ColorManager.primaryColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.dayco.card,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reminder.title.isEmpty ? 'Sans titre' : reminder.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: reminder.done
                            ? TextDecoration.lineThrough
                            : null,
                        color: reminder.done ? Colors.black45 : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reminder.clientName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (reminder.context.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reminder.context,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _tag(
                          icon: Icons.event_outlined,
                          label: _formatDue(reminder.dueAt),
                          color: accent,
                        ),
                        if (reminder.region.isNotEmpty)
                          _tag(
                            icon: Icons.place_outlined,
                            label: reminder.region,
                            color: const Color(0xFF64748B),
                          ),
                        if (overdue)
                          _tag(
                            icon: Icons.warning_amber_rounded,
                            label: 'En retard',
                            color: const Color(0xFFDC2626),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => controller.toggleReminderDone(reminder),
                    icon: Icon(
                      reminder.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    color: reminder.done
                        ? const Color(0xFF16A34A)
                        : context.dayco.shadow,
                    tooltip: reminder.done ? 'Rouvrir' : 'Marquer comme fait',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => controller.deleteReminder(reminder.id),
                    icon: const Icon(Icons.delete_outline, size: 19),
                    color: const Color(0xFFDC2626),
                    tooltip: 'Supprimer',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.alarm_off_outlined,
              size: 48,
              color: context.dayco.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              controller.clientReminders.isEmpty
                  ? "Aucun rappel pour l'instant.\nAjoutez-en depuis la fiche d'un client."
                  : 'Aucun rappel ne correspond à ces filtres.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.dayco.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDue(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year} à $hh:$mi';
  }
}
