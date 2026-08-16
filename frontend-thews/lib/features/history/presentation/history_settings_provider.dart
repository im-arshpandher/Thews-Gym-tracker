import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/presentation/settings_provider.dart';
import 'history_screen.dart';

class HistorySettingsState {
  final HistoryViewMode viewMode;
  final HistoryGroupPeriod groupPeriod;

  const HistorySettingsState({
    this.viewMode = HistoryViewMode.grouped,
    this.groupPeriod = HistoryGroupPeriod.month,
  });

  HistorySettingsState copyWith({
    HistoryViewMode? viewMode,
    HistoryGroupPeriod? groupPeriod,
  }) {
    return HistorySettingsState(
      viewMode: viewMode ?? this.viewMode,
      groupPeriod: groupPeriod ?? this.groupPeriod,
    );
  }
}

class HistorySettingsNotifier extends StateNotifier<HistorySettingsState> {
  final Ref _ref;

  static const String _keyViewMode = 'history_view_mode';
  static const String _keyGroupPeriod = 'history_group_period';

  HistorySettingsNotifier(this._ref) : super(const HistorySettingsState()) {
    _load();
  }

  void _load() {
    final prefs = _ref.read(sharedPreferencesProvider);
    final viewModeStr = prefs.getString(_keyViewMode) ?? 'grouped';
    final groupPeriodStr = prefs.getString(_keyGroupPeriod) ?? 'month';

    HistoryViewMode viewMode;
    switch (viewModeStr) {
      case 'list':
        viewMode = HistoryViewMode.list;
        break;
      case 'calendar':
        viewMode = HistoryViewMode.calendar;
        break;
      case 'grouped':
      default:
        viewMode = HistoryViewMode.grouped;
        break;
    }

    HistoryGroupPeriod groupPeriod;
    switch (groupPeriodStr) {
      case 'date':
        groupPeriod = HistoryGroupPeriod.date;
        break;
      case 'month':
      default:
        groupPeriod = HistoryGroupPeriod.month;
        break;
    }

    state = HistorySettingsState(viewMode: viewMode, groupPeriod: groupPeriod);
  }

  Future<void> setViewMode(HistoryViewMode mode) async {
    state = state.copyWith(viewMode: mode);
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_keyViewMode, mode.name);
  }

  Future<void> setGroupPeriod(HistoryGroupPeriod period) async {
    state = state.copyWith(groupPeriod: period);
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_keyGroupPeriod, period.name);
  }

  Future<void> setGroupedWithPeriod(HistoryGroupPeriod period) async {
    state = HistorySettingsState(
      viewMode: HistoryViewMode.grouped,
      groupPeriod: period,
    );
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_keyViewMode, HistoryViewMode.grouped.name);
    await prefs.setString(_keyGroupPeriod, period.name);
  }
}

final historySettingsProvider =
    StateNotifierProvider<HistorySettingsNotifier, HistorySettingsState>((ref) {
      return HistorySettingsNotifier(ref);
    });
