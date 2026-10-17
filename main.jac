import from walkers { get_state, run_rainfall, acknowledge, fast_forward, submit_report };
import from graph { DashboardState, PersonView, AreaView };

def risk_class(risk: int) -> str {
    return "critical" if risk >= 70 else "high" if risk >= 45 else "watch";
}

cl def:pub app -> JsxElement {
    has state: DashboardState = DashboardState(), role: str = "Resident",
        selected_name: str = "Wanjiku", report_text: str = "Water at the bridge is rising fast.",
        report_area: str = "Mukuru", loading: bool = True, notice: str = "";

    async can with entry {
        state = await get_state();
        loading = False;
    }

    async def rain_changed(event: ChangeEvent) {
        loading = True;
        state = await run_rainfall(int(event.target.value));
        notice = "Rainfall propagation complete — alerts relayed through trust links.";
        loading = False;
    }

    async def mark_safe {
        state = await acknowledge(selected_name);
        notice = selected_name + " is marked safe. The accountability clock has been updated.";
    }

    async def advance_time {
        state = await fast_forward();
        notice = "10 simulated minutes passed — silent vulnerable residents have been escalated.";
    }

    async def send_report {
        if report_text.strip() {
            state = await submit_report(selected_name, report_area, report_text);
            notice = "Report checked against upstream water graph and nearby signals.";
        }
    }

    <main className="wimbi-shell">
        <link rel="stylesheet" href="/styles.css" />
        <header className="topbar">
            <div className="brand"><span className="brand-mark">≈</span><span>Wimbi</span><small>Flood intelligence for Nairobi</small></div>
            <div className="sample-pill">● SAMPLE DATA</div>
            <div className="time-pill">SIMULATION +{state.minute} MIN</div>
        </header>
        <section className="hero">
            <div>
                <p className="eyebrow">AGENTIC FLOOD WARNING</p>
                <h1>Decide who needs to hear what — before the water arrives.</h1>
                <p className="hero-copy">Wimbi follows water downstream, passes alerts through trusted people, and cross-checks what neighbours see.</p>
            </div>
            <div className="rain-control">
                <div className="rain-label"><span>Rainfall intensity</span><strong>{state.rain} mm/hr</strong></div>
                <input aria-label="Rainfall in millimetres per hour" type="range" min="0" max="25" value={str(state.rain)} onChange={rain_changed}/>
                <div className="range-caption"><span>dry</span><span>cloudburst</span></div>
            </div>
        </section>
        <nav className="role-tabs" aria-label="Choose dashboard role">
            {for item in ["Resident", "Community Leader", "Responder Command", "Accountability"] {
                <button className={"role-tab active" if role == item else "role-tab"} onClick={lambda { role = item; }}>{item}</button>
            }}
            <button className="fast-forward" onClick={lambda { advance_time(); }}>Fast-forward 10 min →</button>
        </nav>
        {<div className="notice">{notice}</div> if notice else <div></div>}
        {<ResidentDashboard state={state} name={selected_name} onSafe={mark_safe} reportText={report_text} reportArea={report_area} onText={lambda (e: ChangeEvent) { report_text = e.target.value; }} onArea={lambda (e: ChangeEvent) { report_area = e.target.value; }} onReport={send_report}/> if role == "Resident" else <LeaderDashboard state={state} onRelay={lambda { advance_time(); }}/> if role == "Community Leader" else <CommandDashboard state={state}/> if role == "Responder Command" else <AccountabilityDashboard state={state}/>} 
        <footer><span>WIMBI / Nairobi flood rehearsal</span><span>Graph-informed alerts • Offline-safe templates active</span></footer>
    </main>
}

cl def ResidentDashboard(state: DashboardState, name: str, onSafe: any, reportText: str, reportArea: str, onText: any, onArea: any, onReport: any) -> JsxElement {
    resident = next((p for p in state.people if p.name == name), PersonView());
    area = next((a for a in state.areas if a.name == resident.area), AreaView());
    <section className="resident-frame">
        <div className="phone-head"><span>‹</span><strong>My flood briefing</strong><span>•••</span></div>
        <div className={"warning-card " + risk_class(area.risk)}>
            <p className="tiny-label">PERSONALISED FOR {resident.role.replace("_", " ")}</p>
            <h2>{area.risk}% flood risk in {resident.area}</h2>
            <p>{resident.warning if resident.warning else "Slide rainfall up to generate a trusted warning."}</p>
            <div className="eta-row"><span>WATER ETA</span><strong>{area.eta} min</strong><span className="pulse">● live graph</span></div>
        </div>
        <div className="resident-grid">
            <article className="panel route-panel"><p className="tiny-label">SAFE ROUTE</p><h3>↑ {area.roads if area.roads else "High route pending"}</h3><p>Avoid bridge approaches and low crossings. This route is updated from the water graph.</p></article>
            <article className="panel checklist"><p className="tiny-label">MOVE FIRST</p><ul><li>Documents & medicine</li><li>Power leads above waist height</li><li>Go-bag and phone charge</li></ul></article>
        </div>
        <button className="safe-button" onClick={lambda { onSafe(); }}>{"✓ I'm safe"}</button>
        <section className="report-box"><p className="tiny-label">NEIGHBOUR SIGNAL</p><h3>Report water here</h3><select value={reportArea} onChange={onArea}>{for a in state.areas { <option value={a.name}>{a.name}</option> }}</select><textarea value={reportText} onChange={onText} aria-label="Water report"></textarea><button className="secondary-button" onClick={lambda { onReport(); }}>Send for verification →</button></section>
    </section>
}

cl def LeaderDashboard(state: DashboardState, onRelay: any) -> JsxElement {
    vulnerable = [p for p in state.people if p.vulnerability >= 4];
    <section className="dashboard-grid leader-grid">
        <div className="section-heading"><p className="eyebrow">COMMUNITY LEADER</p><h2>Trust relay circle</h2><p>Alerts travel from ward office through relationships people already use.</p></div>
        <article className="panel trust-graph"><div className="graph-core">Amina<br/><small>ward officer</small></div>{for t in state.trusts { <div className="trust-link"><span>{t.from_name}</span><i>→ {t.weight}/10 →</i><span>{t.to_name}</span></div> }}</article>
        <article className="panel response-panel"><p className="tiny-label">ACKNOWLEDGEMENT STATUS</p>{for p in state.people { <div className="person-row"><span className={"status-dot green" if p.acknowledged else "status-dot red"}></span><strong>{p.name}</strong><small>{p.role.replace("_", " ")}</small><em>{"SAFE" if p.acknowledged else "SILENT"}</em></div> }}<button className="secondary-button" onClick={lambda { onRelay(); }}>Relay to next leader →</button></article>
        <article className="panel vulnerable-panel"><p className="tiny-label">PRIORITY WELFARE CHECKS</p>{for p in vulnerable { <div className="visit-row"><span>⚑</span><div><strong>{p.name}</strong><p>{p.area} · vulnerability {p.vulnerability}/5</p></div><b>{p.relay if p.needs_visit else "monitor"}</b></div> }}</article>
    </section>
}

cl def CommandDashboard(state: DashboardState) -> JsxElement {
    confirmed = [r for r in state.reports if r.status == "confirmed"];
    <section className="dashboard-grid command-grid">
        <div className="section-heading"><p className="eyebrow">RESPONDER COMMAND</p><h2>One operational picture</h2><p>Risk, field signal, and stuck escalations in a single live briefing.</p></div>
        <article className="panel risk-table"><div className="table-title"><h3>Live risk by area</h3><span>{state.rain} mm/hr rain</span></div><div className="table-head"><span>AREA / RIVER</span><span>RISK</span><span>ETA</span><span>ROAD</span></div>{for a in state.areas { <div className="table-row"><span><strong>{a.name}</strong><small>{a.river}</small></span><span className={"risk-number " + risk_class(a.risk)}>{a.risk}%</span><span>{a.eta} min</span><span>{a.roads}</span></div> }}</article>
        <article className="panel reports-panel"><p className="tiny-label">FIELD REPORTS</p>{for r in state.reports { <div className="report-row"><span className={"report-status " + r.status}>{r.status}</span><div><strong>“{r.text}”</strong><p>{r.area} · {r.author}</p><small>{r.reasoning}</small></div></div> }}{<p className="empty">No reports yet. Submit one from Resident view.</p> if not state.reports else <div></div>}</article>
        <article className="panel resource-panel"><p className="tiny-label">AGENT RESOURCE BRIEF</p><h3>Suggested deployment</h3><p>{state.resource_brief}</p><div className="resource-tags"><span>SHELTER</span><span>BOAT</span><span>MEDIC</span></div><p className="stuck">{state.escalations} silence escalation(s) currently need a human visit.</p></article>
        <article className="panel confirmed-panel"><p className="tiny-label">VERIFICATION FEEDBACK</p><h2>{len(confirmed)} confirmed</h2><p>Confirmed reports increase local risk and shorten ETA so operational attention follows both model and lived observation.</p></article>
    </section>
}

cl def AccountabilityDashboard(state: DashboardState) -> JsxElement {
    reached = len([p for p in state.people if p.warning]); acked = len([p for p in state.people if p.acknowledged]); verified = len([r for r in state.reports if r.status == "confirmed"]);
    reach = int(reached * 100 / len(state.people)) if state.people else 0;
    <section className="accountability">
        <div className="section-heading"><p className="eyebrow">ACCOUNTABILITY</p><h2>Did the warning reach people in time?</h2><p>A transparency view for county, funders, and media. Every number is derived from the same sample graph.</p></div>
        <div className="metric-grid"><Metric label="Alert reach" value={str(reach) + "%"} note={str(reached) + " of " + str(len(state.people)) + " warned"}/><Metric label="First acknowledgement" value={str(state.first_ack if state.first_ack else "—") + " min"} note="from rainfall trigger"/><Metric label="Verified report" value={str(state.verified_at if state.verified_at else "—") + " min"} note="from report intake"/><Metric label="Silence escalations" value={str(state.escalations)} note="needs a human visit"/></div>
        <article className="panel bars-panel"><p className="tiny-label">ALERT PATHWAY</p><div className="bar-row"><span>Warning reached</span><div><i style={{"width": str(reach) + "%"}}></i></div><b>{reach}%</b></div><div className="bar-row"><span>Acknowledged</span><div><i style={{"width": str(int(acked * 100 / len(state.people))) + "%"}}></i></div><b>{acked}/{len(state.people)}</b></div><div className="bar-row"><span>Verified reports</span><div><i style={{"width": str(min(100, verified * 50)) + "%"}}></i></div><b>{verified}</b></div></article>
        <article className="panel method-panel"><p className="tiny-label">WHAT THIS MAKES VISIBLE</p><p>Wimbi does not treat delivery as success. It records whether a warning travelled through a trusted connection, was acknowledged, and caused a welfare visit when it did not.</p></article>
    </section>
}

cl def Metric(label: str, value: str, note: str) -> JsxElement {
    <article className="metric"><p>{label}</p><strong>{value}</strong><small>{note}</small></article>
}
