import { VocabCard } from '../data/Db';

export class Schedule {
  ease: number = 2.5;
  reps: number = 0;
  intervalDays: number = 0;
  dueAt: number = 0;
}

export function reviewCard(card: VocabCard, grade: number): Schedule {
  const next = new Schedule();
  next.ease = card.ease;
  next.reps = card.reps;
  next.intervalDays = card.intervalDays;
  if (grade <= 0) {
    next.reps = 0;
    next.intervalDays = 0;
    next.ease = card.ease - 0.2;
    if (next.ease < 1.3) {
      next.ease = 1.3;
    }
    next.dueAt = Date.now() + 10 * 60 * 1000;
    return next;
  }
  next.reps = card.reps + 1;
  if (next.reps === 1) {
    next.intervalDays = 1;
  } else if (next.reps === 2) {
    next.intervalDays = 3;
  } else {
    next.intervalDays = Math.round(card.intervalDays * card.ease);
  }
  if (grade >= 2) {
    next.intervalDays = Math.round(next.intervalDays * 1.3);
    next.ease = card.ease + 0.1;
  }
  if (next.intervalDays < 1) {
    next.intervalDays = 1;
  }
  next.dueAt = Date.now() + next.intervalDays * 24 * 60 * 60 * 1000;
  return next;
}
