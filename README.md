# macOS architecture skill

Architectural decisions for native macOS apps built with SwiftUI and AppKit, packaged as an
installable skill. It is the **decision layer** — where state lives, which structure to choose and
why, and which patterns have already cost time. It deliberately does not cover API reference
material: that is what the companion skills are for.

**Stack:** SwiftUI + AppKit · `@Observable` · Swift 6 concurrency · Swift Testing · SwiftPM

**Admission rule:** something gets in only if it is an architectural pattern with its rationale, a
fact verified against real code or measurements, or an anti-pattern that has already cost time. See
[SKILL.md](.agents/skills/macos-app-architecture/SKILL.md).

## Install

This repository is **private**, so `npx skills add` needs credentials for it. Any of these works —
the CLI clones over git and falls back to `gh` and SSH:

```bash
# HTTPS, using your gh / git credential helper (gh auth status to check)
npx skills add gerardp/macos-architecture-skills

# SSH, if your HTTPS credentials are not set up
npx skills add git@github.com:gerardp/macos-architecture-skills.git

# CI, or a machine with no interactive auth
GITHUB_TOKEN=<token with repo scope> npx skills add gerardp/macos-architecture-skills
```

That installs one skill, `macos-app-architecture`, into `.agents/skills/` (add `-g` to install it
for every project instead of the current one). Everything else in this repository — the README, the
license, `AGENTS.md` — stays here: the skill is the `.agents/skills/macos-app-architecture/`
directory and nothing else.

### Companion skills

This skill expects them, does not republish them, and does not duplicate their content. The full
table with what each one covers is in
[SKILL.md](.agents/skills/macos-app-architecture/SKILL.md#companion-skills), including the ones that
are **deliberately not installed** and why:

```bash
npx skills add https://github.com/emilkowalski/skills --skill write-swift
npx skills add https://github.com/avdlee/swiftui-agent-skill --skill swiftui-expert-skill
npx skills add https://github.com/avdlee/swift-concurrency-agent-skill --skill swift-concurrency
npx skills add https://github.com/avdlee/swift-testing-agent-skill --skill swift-testing-expert
npx skills add https://github.com/CharlesWiltgen/Axiom --skill axiom-macos
npx skills add https://github.com/steipete/agent-scripts --skill instruments-profiling
npx skills add https://github.com/Dimillian/Skills --skill macos-spm-app-packaging
```

## Layout

<pre>
.agents/skills/macos-app-architecture/
  <a href=".agents/skills/macos-app-architecture/SKILL.md">SKILL.md</a>                 Entry point. 13 quick rules, the index, and the companion-skill table.
  <a href=".agents/skills/macos-app-architecture/CHANGELOG.md">CHANGELOG.md</a>             Semver policy + what every rule change invalidated.
  references/
    <a href=".agents/skills/macos-app-architecture/references/architecture.md">architecture.md</a>        MV, bounded-context stores, Environment, Screens vs. Views, event enums.
    <a href=".agents/skills/macos-app-architecture/references/antipatterns.md">antipatterns.md</a>        What not to do, wrong and right code side by side.  ← start here
    <a href=".agents/skills/macos-app-architecture/references/overrides.md">overrides.md</a>           Where this skill overrides a companion skill, with the citation.
    <a href=".agents/skills/macos-app-architecture/references/ownership.md">ownership.md</a>           Who owns each piece of data: State, Binding, Bindable, Environment.
    <a href=".agents/skills/macos-app-architecture/references/observation.md">observation.md</a>         @Observable granularity (measured), lifecycle, event enums.
    <a href=".agents/skills/macos-app-architecture/references/view-composition.md">view-composition.md</a>    Generic @ViewBuilder, dedicated views, not passing the whole model.
    <a href=".agents/skills/macos-app-architecture/references/navigation.md">navigation.md</a>          Selection vs. stack, what does not carry over from iOS, windows.
    <a href=".agents/skills/macos-app-architecture/references/validation.md">validation.md</a>          Five form-validation patterns, least to most machinery.
    <a href=".agents/skills/macos-app-architecture/references/error-handling.md">error-handling.md</a>      Error severity, LocalizedError, presentation, typed throws.
    <a href=".agents/skills/macos-app-architecture/references/undo.md">undo.md</a>                UndoManager as a system responsibility, not hand-rolled Memento.
    <a href=".agents/skills/macos-app-architecture/references/previews.md">previews.md</a>            Previews as a design criterion. Narrow inputs, named states.
    <a href=".agents/skills/macos-app-architecture/references/testing.md">testing.md</a>             What deserves a test and which kind.
    <a href=".agents/skills/macos-app-architecture/references/project-structure.md">project-structure.md</a>   Flat, feature-based, with Stores/ outside Features/.
    <a href=".agents/skills/macos-app-architecture/references/swift-idioms.md">swift-idioms.md</a>        Only what write-swift does not cover.
    <a href=".agents/skills/macos-app-architecture/references/longevity.md">longevity.md</a>           Soft-deprecation, third-party rot, toolchain drift.

<a href="AGENTS.md">AGENTS.md</a>                  How to work on this repository. For tools that read AGENTS.md.
<a href="CLAUDE.md">CLAUDE.md</a>                  Pointer so Claude Code auto-loads AGENTS.md.
</pre>

Three documents are planned and not written yet — `appkit-bridge.md`, `text-editing.md` and
`distribution.md`. The index lists them under *Planned, not written yet*, and nothing links to them.

## Keeping it current

```bash
# on a branch, never on main
git switch -c chore/update-skills
npx skills update macos-app-architecture
git diff .agents/skills/          # ← this step is not optional
```

Name the skill. A bare `npx skills update` updates every skill you have installed, globally and
locally, which is a separate decision each time.

**Read the diff.** The `skills` CLI has no pinning: `add` takes no ref or tag, and `update` always
resolves the repository's default branch, so an update can change the rules your agents follow
without you noticing. The defence is that `.agents/skills/` is committed in your project — the
update lands as a reviewable diff, and
[the skill's CHANGELOG](.agents/skills/macos-app-architecture/CHANGELOG.md) lands inside that same
diff with the reasoning. A **major** bump means a rule got stricter and code that passed review
before may not now. If an update is not something you want yet,
`git restore .agents/skills/macos-app-architecture` puts it back.

## Maintaining the skill

- **Adding a rule?** It has to clear the admission rule in `SKILL.md`: a pattern with its rationale,
  a verified fact, or an anti-pattern that has cost time. API reference material belongs in a
  companion skill, not here.
- **A companion skill is wrong or outdated?** Do not argue with it in the abstract. Record it in
  [overrides.md](.agents/skills/macos-app-architecture/references/overrides.md) citing skill, file
  and line, and state whether it is obsolescence or design disagreement — they age differently.
- **Changed a rule?** Bump `metadata.version` in `SKILL.md` and add the entry to
  [the CHANGELOG](.agents/skills/macos-app-architecture/CHANGELOG.md) **in the same commit**, then
  tag `v<version>`. The versioning policy is at the top of that file.

## License

MIT — see [LICENSE](LICENSE).
