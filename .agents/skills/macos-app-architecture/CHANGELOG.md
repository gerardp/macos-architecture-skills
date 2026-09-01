# Changelog — macos-app-architecture

This file ships **inside the skill**, on purpose. `npx skills update macos-app-architecture`
overwrites `.agents/skills/macos-app-architecture/` in place, so the changelog has to arrive in the
same diff as the rules it describes. A changelog left behind in the source repository is one the
consumer never sees.

## What the version number means

`metadata.version` in [SKILL.md](SKILL.md) is semver, and the question it answers is *"can code that
passed review yesterday fail today?"*

| Bump | Means | Consumer action |
| --- | --- | --- |
| **MAJOR** | A rule got stricter: a new Quick Rule, a new anti-pattern existing code can violate, a new override of a companion skill, or a change to which companion skills must be installed. Compliant code can stop being compliant. | Read the entry. It names what it invalidates and what to do. |
| **MINOR** | New ground covered **that invalidates nothing**: a reference file about a subject the codebase has not touched yet, a rationale made explicit, better examples. | Read at leisure. |
| **PATCH** | Wording, links, formatting, a re-verification date. No rule changed. | None. |

The invalidation test governs, and it beats the category every time. "Previously unspecified" is
**not** a reason to call something MINOR: a first rule about an unaddressed subject is MAJOR the
moment existing code can violate it. If you have to think about whether anything breaks, you already
have your answer — bump MAJOR.

**Every MAJOR entry states what it invalidates and how to comply.** That is the same bar
[overrides.md](references/overrides.md) puts on an override of a third-party skill: a change without
a stated consequence becomes silent drift by accident.

Release procedure: bump `metadata.version` in `SKILL.md` and add the entry here **in the same commit
as the rule change**, then tag `v<version>`.

## 1.0.0 — 2026-09-01

First packaged release. The skill moved from the repository root to
`.agents/skills/macos-app-architecture/` so it can be installed with `npx skills add`, and gained
`license` and `metadata.version` in its frontmatter.

No rule changed. The 15 reference documents, the Quick Rules and the companion-skill table are the
content that already existed.
