# Wimbi

Wimbi is a graph-native Nairobi flood-warning control room built in Jac. Rainfall risk flows downstream through connected areas, while warnings propagate through trusted community relationships. All sample people, areas, rivers, roads and reports are fictional.

## Run

```bash
jac install
jac start main.jac
```

Open the app URL shown by the command. Optional model calls use the configured byLLM provider; role-aware template warnings and deterministic report/resource fallbacks keep the demo usable without a model key.

## Control room

- **Responder:** adjust simulated rainfall, inspect downstream area risk and roads, fast-forward time, review welfare escalations and reports.
- **Leader:** inspect trust relationships, relay alerts, and confirm welfare visits.
- **Resident:** view a role/language-specific briefing, acknowledge safety, and submit water observations.
- **Accountability:** monitor acknowledgement reach, response durations, and escalation counts.
- **SMS/USSD:** try `ACK|<name>`, `REPORT|<area>|<text>`, or `STATUS|<area>`.

Use **Reset demo** to restore the baseline graph. Rain below 30 mm/hr clears warnings; higher rain follows areas downstream. Report verification adds a persistent local risk boost which remains after rainfall changes.

## Jac implementation

`graph.jac` declares the OSP nodes, typed edges and snapshot objects. `walkers.jac` implements graph traversal, propagation, safety acknowledgements, reports, welfare visits, reset and USSD commands as typed Jac functions and walkers. `main.jac` is the client UI. `public/styles.css` contains the presentation styles.
