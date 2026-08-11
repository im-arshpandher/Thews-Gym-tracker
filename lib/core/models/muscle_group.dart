enum MuscleGroup {
  all('All'),
  forearms('Forearms'),
  chest('Chest'),
  core('Core / Abs'),
  legs('Legs'),
  back('Back'),
  biceps('Biceps'),
  triceps('Triceps'),
  shoulders('Shoulders'),
  neck('Neck'),
  arms('Arms'),
  cardio('Cardio'),
  fullBody('Full Body');

  final String label;
  const MuscleGroup(this.label);

  static MuscleGroup fromString(String val) {
    final lower = val.toLowerCase().trim();
    if (lower.contains('forearm')) return MuscleGroup.forearms;
    if (lower.contains('bicep')) return MuscleGroup.biceps;
    if (lower.contains('tricep')) return MuscleGroup.triceps;
    if (lower.contains('neck')) return MuscleGroup.neck;
    if (lower.contains('abs') || lower == 'core') return MuscleGroup.core;
    return MuscleGroup.values.firstWhere(
      (e) =>
          e.label.toLowerCase() == lower ||
          e.name.toLowerCase() == lower,
      orElse: () => MuscleGroup.fullBody,
    );
  }
}
