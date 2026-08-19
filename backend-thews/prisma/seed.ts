import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const defaultExercises = [
  { name: 'Barbell Bench Press', muscleGroup: 'Chest', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Incline Dumbbell Press', muscleGroup: 'Chest', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Cable Chest Fly', muscleGroup: 'Chest', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Barbell Squat', muscleGroup: 'Legs', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Romanian Deadlift', muscleGroup: 'Hamstrings', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Leg Press', muscleGroup: 'Legs', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Barbell Deadlift', muscleGroup: 'Back', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Pull-Up', muscleGroup: 'Back', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Lat Pulldown', muscleGroup: 'Back', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Barbell Overhead Press', muscleGroup: 'Shoulders', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Dumbbell Lateral Raise', muscleGroup: 'Shoulders', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Barbell Bicep Curl', muscleGroup: 'Arms', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Tricep Rope Pushdown', muscleGroup: 'Arms', category: 'weight_reps', enabledMetrics: 'weight,reps' },
  { name: 'Outdoor Run', muscleGroup: 'Cardio', category: 'distance_duration', enabledMetrics: 'distance,duration,pace' },
  { name: 'Treadmill Run', muscleGroup: 'Cardio', category: 'distance_duration', enabledMetrics: 'distance,duration,incline,speed' },
];

async function main() {
  console.log('🌱 Seeding default exercises...');
  for (const ex of defaultExercises) {
    const existing = await prisma.exercises.findFirst({
      where: { name: ex.name, userId: null },
    });
    if (!existing) {
      await prisma.exercises.create({
        data: {
          ...ex,
          isCustom: false,
        },
      });
    }
  }
  console.log('✅ Default exercises seeded successfully.');
}

main()
  .catch((e) => {
    console.error('Seeding error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
