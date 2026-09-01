# Agent instructions

This repository **is** a skill. Its product is the directory
`.agents/skills/macos-app-architecture/`, installed into other projects with `npx skills add`.
Everything outside that directory is packaging: it is never installed and never read by a consumer.

## What you are editing

**[.agents/skills/macos-app-architecture/SKILL.md](.agents/skills/macos-app-architecture/SKILL.md)** —
the entry point. It holds the admission rule, the index of reference documents, the quick rules and
the companion-skill table. Read it before changing anything under `references/`.

There is no application code here — only Markdown. The Swift in this repository lives inside the
reference documents as examples, and is there to show a pattern, not to be compiled.

## Rules for changing the skill

1. **The admission rule is binding.** Content gets in only if it is an architectural pattern with
   its rationale, a fact verified against real code or measurements, or an anti-pattern that has
   already cost time — with the code that shows what not to do. API reference material that a
   companion skill already covers stays out, however useful it seems.
2. **Do not contradict a companion skill silently.** If `swiftui-expert-skill`, `write-swift`,
   `axiom-macos` or any other installed skill says something this skill disagrees with, record it in
   [references/overrides.md](.agents/skills/macos-app-architecture/references/overrides.md) with the
   skill, file and line, and say whether it is obsolescence or design disagreement. Without a
   citation it is not an override, it is an opinion.
3. **Verify before you claim something is obsolete.** "This no longer compiles" and "this is no
   longer the API" are checkable. Check them.
4. **Every rule change is a release.** Bump `metadata.version` in `SKILL.md` and add the entry to
   [CHANGELOG.md](.agents/skills/macos-app-architecture/CHANGELOG.md) in the **same commit**, then
   tag `v<version>`. The semver policy — what counts as major for a rule rather than for code — is at
   the top of that file. MAJOR entries must state what they invalidate.
5. **Keep the index honest.** New reference file → add its row to the index table in `SKILL.md`.
   A row under *Planned, not written yet* is unwritten; do not link to a file that does not exist.
6. **Relative links only.** Links inside the skill must resolve after installation, where the skill
   sits in a consumer's `.agents/skills/` and this repository's root does not exist.

## Language

The skill is written in English. Keep it that way, whatever language the conversation is in.
