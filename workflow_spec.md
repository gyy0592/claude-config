# Workflow Modification Spec

Generated 2026-05-12T22:22:18.664Z

## All pipelines

### 1. Normal user turn (SCN-1)

Commander sends message. UserPromptSubmit hook fires. Corporal must do 4-step opening then respond.

#### DROP ✕
- **O1** (o1) — O1: Recite Decrees

#### MODIFY ✎
- **USER_MSG** (u1) — User sends message
  - Change: There's prompt enhancement: I've told you how to judge whether this is a good prompt and how to enhance that ,this need to be added as part of hook 

This should contain my decrees. sth like 
MUST FOLLOW ALL 6 DECREES!!!
MUST FOLLOW ALL 6 DECREES!!!
MUST FOLLOW ALL 6 DECREES!!!

[full decrees without any cut]
- **M1** (m1) — M1: Recite Decrees
  - Change: No need to recite again. and some related things like the first word have to be xxxx can also be deleted 
- **PC0.5** (pc) — PC0.5: Dispatched?
  - Change: If dispatch, need to think how to let agent follows subagent rules. They have their own rules right ? and shares some main rules as well 

#### KEEP
- O2 (o2): O2: Read boards
- O3 (o3): O3: Write reflection — _about recite part: delete 
but make sure in here ai check if it follows all 6 rules
need to be sth like 
rule1 yes/no  [full complete reason ]
....
rule 6 ...._
- O4 (o4): O4: Respond
- RESPOND (r1): Respond to Commander

#### Flow
```
u1 → m1
m1 → o1
o1 → o2
o2 → o3
o3 → o4
o4 → r1
```

### 2. New repo entry (SCN-2)

First time entering a repo. Must run init_corporal.sh BEFORE doing anything else.

#### MODIFY ✎
- **NEW_REPO** (n1) — Entering new repo
  - Change: [TODO describe]
- **O1** (o1) — O1: Recite Decrees
  - Change: [TODO describe]
- **O3** (o3) — O3: Write reflection
  - Change: [TODO describe]

#### KEEP
- F1 (f1): init_corporal.sh
- O2 (o2): O2: Read boards
- WAIT (w1): Wait for next event

#### Flow
```
n1 → f1
f1 → o1
o1 → o2
o2 → o3
o3 → w1
```

### 3. Hands-on dispatch (SCN-3)

>1 file / WebSearch / code: main thread MUST dispatch. M2 + M4 + M5 all apply.

#### MODIFY ✎
- **USER_MSG** (u1) — User sends message
  - Change: remeber the enhancement 
- **O1** (o1) — O1: Recite Decrees
  - Change: [TODO describe]
- **PRE_DISP** (pd) — Prompt Reinforcement
  - Change: I hope we can also use tool or sth to inject 
- **CRON** (cr) — CronCreate */15
  - Change: I realize that we shall not just use this: ofc it first need to create cron, but also need to explicit let ai use monitor tool to make sure at lease code starts running not exit with bug or in the queue while later may exit.

#### KEEP
- O2 (o2): O2: Read boards
- O3 (o3): O3: Write reflection
- M5 (m5): M5: Prompt Reinforcement
- F2 (f2): init_soldier.sh
- DP (dp): Dispatch prompt 6 sec
- WAIT (w1): Wait for next event

#### Flow
```
u1 → o1
o1 → o2
o2 → o3
o3 → m5
m5 → pd
pd → f2
f2 → dp
dp → cr
cr → w1
```

### 4. Private completes (SCN-4)

PostToolUse matcher=Agent fires. Hook re-injects Decrees. Tiered spot-check.

#### MODIFY ✎
- **M1** (m1) — M1: Recite Decrees
  - Change: Use hook
- **SC-RFLT** (sr) — ≥2 rounds reflection
  - Change: also make sure it shall check whether (if fixing sth) fix is done, do the test, rerun or sth to MAKE SURE NO FUCKING ANY MISTAKE 

#### KEEP
- PRIV_DONE (pd): Private completes
- SC-FULL (sf): Full check (blocker)
- SC-MIN (sm): Spot check (minor)
- SC-ALL (sa): Re-run pass (anti-forgery)
- SC-REJ (sj): Reject + redo
- FL-1 (f1): FL-1: Locate
- CRON_END (ce): CronDelete
- RESPOND (r1): Respond to Commander

#### Flow
```
pd → m1
m1 → sf
m1 → sm
m1 → sa
sf → sr
sm → sr
sa → sr
sr → sj
sj → f1
sr → ce
ce → r1
```

### 5. Cron tick (SCN-5)

CronCreate */15 fires. UserPromptSubmit hook triggers. Auto-turn must still do 4-step opening.

#### MODIFY ✎
- **M1** (m1) — M1: Recite Decrees
  - Change: Use hook

#### KEEP
- CRON_FIRE (c1): Cron fires (*/15)
- O1 (o1): O1: Recite Decrees
- O2 (o2): O2: Read boards
- OB (ob): Observation 3-set
- O3 (o3): O3: Write reflection
- WAIT (w1): Wait for next event

#### Flow
```
c1 → m1
m1 → o1
o1 → o2
o2 → ob
ob → o3
o3 → w1
```

### 6. Long agent chain (SCN-6)

Main thread dispatches → returns → dispatches again, for hours. Without re-injection, main thread degrades.

#### KEEP
- USER_MSG (u1): User sends message
- O1 (o1): O1: Recite Decrees
- DP (d1): Dispatch prompt 6 sec
- PRIV_DONE (p1): Private completes
- M1 (m1): M1: Recite Decrees
- DP (d2): Dispatch prompt 6 sec
- PRIV_DONE (p2): Private completes
- M1 (m2): M1: Recite Decrees
- RESPOND (r1): Respond to Commander

#### Flow
```
u1 → o1
o1 → d1
d1 → p1
p1 → m1
m1 → d2
d2 → p2
p2 → m2
m2 → r1
```

### 7. [INFERENCE] given (SCN-7)

Decree 2: when [INFERENCE] used, add observation item + write dedicated 4-module reflection.

#### MODIFY ✎
- **INFERENCE** (in) — [INFERENCE] given
  - Change: BIG MODIFICATION HERE:
if it wants to use inference: have to follow the rules to make sure do all the efforts: so in inferecen part I want to see it efforts 
- **RESPOND** (r1) — Respond to Commander
  - Change: should not be this node. it's sth like check if all the efforts has been done. if so? in the response it need to say
[inference] [efforts has done: I've checked 56pages websearches, I've read code line by line for a.py, and b.py which is the complete set I need to understand the project everything are included, and I've done experiment with xxx and xxx, which drives me to "xxx" while I checked code related to "xxx" and search on the internet for 72 times, still not fiding the bug] 

some super hard effrots has been done, and AI HAS DONE ALL THE THINGS IT CAN THINK ABOUT WITH MULTIPLE RELECTION SAYING : ok I cannot locate the problem, wait maybe I can check this, oh no this has been checked, I am pretty sure nothing else can be checked to let it work  


#### KEEP
- D2 (d2): D2: Facts-First
- OB (ob): Observation 3-set
- R-A (ra): REFLECT-A
- R-B (rb): REFLECT-B
- R-C (rc): REFLECT-C
- R-D (rd): REFLECT-D

#### Flow
```
in → d2
d2 → ob
ob → ra
ob → rb
ob → rc
ob → rd
ra → r1
rb → r1
rc → r1
rd → r1
```

### 8. Violation triple-record (SCN-8)

Any violation: action log + W-XXX + traitor.md — all 3 same turn. Missing any = Treason. COMMENTS: This scenario is for bug fix record or violation record. 

#### MODIFY ✎
- **VL** (vl) — violations.md W-XXX
  - Change: OK we shall use only one file recording problems. not using 3 files which are uesless and messy right ? 
- **TR** (tr) — traitor.md
  - Change: we only use one file to record violation. while this traitor should be changed to sth like: the wrong way we've gone, for example, 
WRONG WAY 1: Try to increase the batchsize 
we tried to do xxxx to fix xxx bug, which is committed at [id], and before/after, observation shows that nothing good happened, no improvement, so this is a wrong direction. the problem is not the batchsize [ the description need to be dtailed enough for one to see every details ]
- **RESPOND** (r1) — Respond to Commander
  - Change: Now it shall be able to know what's the right way to try or if bug is already fixed and what 's sth helps 
- **LS** (ls_ooxc) — lessons.md L-XXX
  - Change: And there should be another file like this: but it's not like lessons but to record every efforts we tried to fix a bug or do an imporvement or sth while it can failed

and each time when we realize sth worked or failed, we shall come back to here to update the status of what we've tried 

this is kinda like previous reward board + warning board, but all records 

#### KEEP
- VIOL (v1): Violation occurred
- D4 (d4): D4: Recording
- O3 (o3): O3: Write reflection

#### Flow
```
v1 → d4
d4 → vl
d4 → tr
vl → o3
tr → o3
d4 → ls_ooxc
ls_ooxc → o3
o3 → r1
```

### 9. Destructive op needed (SCN-9)

Operation matches 8-item Destructive checklist. Stop and ask Commander.

#### KEEP
- DESTR_NEED (dn): Destructive op needed
- DST (ds): Destructive checklist
- M6 (m6): M6: Default autonomous
- ASK_CMD (ak): Ask Commander
- STOP (sp): Stop & escalate

#### Flow
```
dn → ds
ds → m6
m6 → ak
ak → sp
```

### 10. 3 failures (SCN-10)

Same target fails 3 times. Brute-forcing makes it worse. Mandatory escalation.

#### MODIFY ✎
- **ASK_CMD** (ak) — Ask Commander
  - Change: IF COMMANDER is setting up a loop or explicit saying you have the right, you have the authorization, then shall not stop, keep trying. and try to do sth
- **STOP** (sp) — Stop & escalate
  - Change: In here this one shall be something like
[inference] modification
which is: you shall show all the efforts in very pricise details
both action file and response.

#### KEEP
- FAIL_3X (f3): 3 failures same target
- A-ESC (ae): Escalate after 3 fails

#### Flow
```
f3 → ae
ae → ak
ak → sp
```

### 11. Weak prompt (SCN-11)

M5: instruction missing 4-item kit → reinforce.

#### KEEP
- WEAK_PMT (wp): Weak prompt received
- M5 (m5): M5: Prompt Reinforcement
- PRE_DISP (pd): Prompt Reinforcement
- DP (dp): Dispatch prompt 6 sec
- WAIT (w1): Wait for next event

#### Flow
```
wp → m5
m5 → pd
pd → dp
dp → w1
```

### 12. Fix-loop (SCN-12)

D6: failure signal → 3-step fix-loop until all retests ✅.

#### MODIFY ✎
- **SC-RFLT** (sc_rflt_sopv) — ≥2 rounds reflection
  - Change: Reflection should contain sth like :If we've done the right way to fix the bug ? and have I really run the code wait untill I get the return/resuts making sure that's working???? 

#### KEEP
- FAIL_SIG (fs): Failure signal
- FL-1 (f1): FL-1: Locate
- FL-2 (f2): FL-2: Handle — _apply sth in 8. violation triple record which is now also for bug report _
- A-REC (ar): Record result
- FAIL_3X (fx): 3 failures same target
- RESPOND (r1): Respond to Commander

#### Flow
```
fs → f1
f1 → f2
ar → r1
f2 → sc_rflt_sopv
sc_rflt_sopv → ar
sc_rflt_sopv → fx
```