---
name: gen-draft
description: "Generate a high-level draft document (draft.md) from a user's task description. Use ONLY when the user explicitly invokes /gen-draft or says '写draft', '生成draft'. Never trigger automatically. The draft captures WHAT and WHY, never HOW."
---

# Gen Draft — Entry Point

The draft pipeline has **two mandatory phases**. They are sequential and cannot be merged.

## Phase 1: Gather (ALWAYS first)

Read `/home/yguo173/.claude/skills/gen-draft/1_gather.md` and execute it completely.

**HARD STOP**: Do not read `2_write.md`. Do not write any draft content. Do not generate section headers.
Your only job right now is to ask the user questions and wait for their answers.

You are done with Phase 1 when: the user has answered your questions in this conversation.

## Phase 2: Write (only after user replies)

Once the user has responded to your Phase 1 questions, read `/home/yguo173/.claude/skills/gen-draft/2_write.md` and execute it.

Use the user's answers to fill in the draft. Do not invent values for anything the user left unanswered — mark those as `⚠ not specified`.
