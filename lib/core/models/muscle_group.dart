enum MuscleGroup {
  all('All'),
  chest('Chest'),
  back('Back'),
  legs('Legs'),
  shoulders('Shoulders'),
  arms('Arms'),
  core('Core'),
  cardio('Cardio'),
  fullBody('Full Body');

  final String label;
  const MuscleGroup(this.label);

  static MuscleGroup fromString(String val) {
    return MuscleGroup.values.firstWhere(
      (e) =>
          e.label.toLowerCase() == val.toLowerCase() ||
          e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MuscleGroup.fullBody,
    );
  }
}
