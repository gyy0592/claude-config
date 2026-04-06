# gen-draft Eval Results — Iteration 1

## Eval 0: training-run-asks-naming

**Prompt**: LSTM PTB learning rate ablation on Slurm, 2 GPUs. /gen-draft

| Assertion | with-skill | baseline |
|-----------|-----------|---------|
| draft_file_created | ✓ PASS | ✓ PASS |
| run_naming_in_constraints | ✓ PASS — user-selected categories, concrete template | ✓ PASS — but AI chose format unilaterally (no user input) |
| askuserquestion_called | ✓ PASS — triggered, multiSelect presented | ✗ FAIL — baseline decided format without asking |
| execution_order_tagged | ✓ PASS — all steps have [independent]/[depends] tags | ✗ FAIL — no tagged execution order section |
| no_implementation_details | ✓ PASS | ✗ FAIL — outputs described with column names ("epoch, train_loss, ...") |
| decision_points_table | ✓ PASS | ✗ FAIL — "Open Questions" section lacks options/trade-offs |

**Verdict**: with-skill wins on 4/6 assertions. Both create a naming template, but:
- Skill asks user → naming reflects user's choices
- Baseline guesses → naming is AI-chosen without validation
- Skill enforces structural checks (tags, no implementation details)
- Baseline produces a looser, partially useful draft

## Key Finding

The updated skill successfully triggers AskUserQuestion for run naming when the task is an ablation/training experiment. The trigger condition ("one output directory per run") correctly fires. The multiSelect question with 6 categories is presented and the user's answer is locked into Constraints as a concrete template.

The baseline sometimes happens to include a naming template by coincidence, but it's AI-chosen (not user-validated) and may not match the user's actual naming preferences (as seen in the MQAR experiment where the user specifically wanted gpu_type, node, and job_id encoded).
