pragma circom 2.1.6;

/*
  soul_score.circom
  Public input: violations
  Public output: soul_score = max(0, 100 - violations)
*/

template SoulScore() {
    signal input violations;
    signal output soul_score;

    // simple arithmetic
    soul_score <== 100 - violations;
}

component main = SoulScore();
