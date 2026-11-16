# Agent notes

## Model and harness continuity

The user intentionally switches models and agent harnesses to discover different strengths and perspectives. Keep useful context portable across those switches.

- At the first substantive work session, record a dated baseline in the project's existing work log: harness, model identifier/version when explicitly available, and the source of that information (session metadata or user report). If a baseline already exists, record only a known change. Mark unavailable details as `unknown`; do not infer identity from writing style, repository configuration, or past agents, and do not interrupt work just to ask.
- When a model or harness change is known, append a short entry with the previous and current combination, date, current task, and starting revision/working-tree state when relevant. Do not invent the previous combination or rewrite historical attribution. A new session alone is not evidence of a switch.
- At handoff or the end of substantive work, record what changed, evidence/checks and their results, unresolved claims or blockers, and the next concrete experiment. Update existing project/resume notes with durable decisions and current status; link to the worklog entry instead of duplicating it. Preserve accepted constraints and account for pre-existing uncommitted work.
- Note useful insights found after a switch, but separate observed results from hypotheses about model/harness strengths. A fresh perspective, changed context, and changed code can also explain improvements. Record time/cost only when actually measured or reported.
- Reuse the existing log and notes conventions. If no work log exists, create `WORKLOG.md` at the project root when substantive work warrants an entry. Keep entries concise; do not log every tool call or duplicate entries because this guidance appears in multiple AGENTS.md files. Do not copy credentials, private transcripts, or sensitive payloads into logs.

Suggested entry: `Date | harness/model (source; previous → current if known) | task/revision | changes and verified results | open questions | next step`.
