/// Career stages (plan section 5). Promotion thresholds live in
/// `CareerSystem`; the stage itself is plain data so it persists cleanly.
enum CareerStage {
  student('Student'),
  phd('PhD'),
  postdoc('Postdoc'),
  professor('Professor');

  const CareerStage(this.label);
  final String label;
}

class CareerState {
  CareerStage stage = CareerStage.student;
  bool thesisDefended = false;
  int apprentices = 0; // narrated automation (students), phase 3+

  CareerState({
    this.stage = CareerStage.student,
    this.thesisDefended = false,
    this.apprentices = 0,
  });

  CareerState copy() => CareerState(
        stage: stage,
        thesisDefended: thesisDefended,
        apprentices: apprentices,
      );
}
