# Wimbi — agentic flood warning demo

Wimbi is a demo-ready Nairobi flood-warning system written primarily in **Jac**. It does not just map water: it decides who should hear a warning, through which trusted person, and verifies new reports against water and neighbour signals.

> **Sample data** — all people, areas, rivers, roads, and reports are fictional demonstration data.

## Run

The current Jac release documents prebuilt macOS/Linux binaries; on Windows, run inside WSL or use a supported Jac setup.

```bash
jac install
jac run
```

Open `http://localhost:8000`. Set a LiteLLM-compatible model/API key if desired. The demo remains usable with no model: every `by llm()` function is wrapped with a deterministic template fallback.

## Demo flow

1. Move the rainfall slider upward.
2. Watch downstream areas turn high/critical and alerts fan through the trust graph.
3. Use **Fast-forward 10 min** to escalate silent, vulnerable residents to a trusted neighbour visit.
4. In **Resident**, submit the prefilled bridge report.
5. In **Responder Command**, see the report verification and corrected risk; then open **Accountability** for the outcome metrics.

## How Jac/Jaseci is used

- `graph.jac` is the seed and model. `Area`, `River`, `DrainagePoint`, `Road`, `Person`, and `Report` are Jac nodes; `FlowsTo`, `Connects`, `Trusts`, `LocatedIn`, and `ReportedAt` are typed graph edges.
- `walkers.jac` contains four Jac walkers: `RiskPropagator`, `WarningRelay`, `SilenceEscalator`, and `ReportVerifier`. They traverse and mutate the graph rather than query a separate database.
- `main.jac` is the Jac client UI (`cl def:pub app`). Calls such as `await run_rainfall(...)` are compiler-generated typed client/server bridges—there is no hand-written REST client, API route, ORM, React project, or Supabase.
- Three typed `by llm()` functions produce role/language warnings, verification rationale, and response resource briefs. `try/except` fallbacks guarantee the exercise works without a model key.

## Files

- `graph.jac` — graph nodes, edges, sample seed data, and LLM declarations
- `walkers.jac` — the agent walkers, public actions, and dashboard snapshot projection
- `main.jac` — all four dashboard views in Jac client syntax
- `public/styles.css` — visual styling only

The frontend and backend logic are Jac; the CSS file is the only presentation-only asset.
