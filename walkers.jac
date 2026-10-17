
import from graph { DashboardState, AreaView, PersonView, ReportView, TrustView, seed_sample_data, control, area_for, area_by_name, person_by_name, template_warning, route_for, Area, River, Person, Report, FlowsTo, Feeds, Connects, LocatedIn, ReportedAt, Trusts, personalised_warning, verification_reason, resource_brief }

walker RiskPropagator {
    has rain: int = 0;
    can begin with Root entry {
        seed_sample_data(); c = control(); c.rain = self.rain;
        for river in [root-->[?:River]] { river.rain_mm_hr = self.rain; visit river; }
    }
    can enter_river with River entry { visit [here->:Feeds:->[?:Area]]; }
    can score_area with Area entry {
        factor = 5 if here.river == "Nairobi River" else 4;
        score = self.rain * factor + here.order * 9 + here.boost;
        if self.rain < 30 { score = 8 + here.boost; }
        if score < 5 { score = 5; }
        if score > 100 { score = 100; }
        here.risk = score; here.eta = max(12, 180 - score * 2 + here.order * 7);
        here.trend = "critical" if score >= 70 else "high" if score >= 45 else "watch";
        for road in [here->:Connects:->[?:Road]] { road.status = "avoid" if score >= 65 else "caution" if score >= 35 else "open"; }
        visit [here->:FlowsTo:->[?:Area]];
    }
}
walker WarningRelay {
    can begin with Root entry {
        seed_sample_data(); c=control();
        if c.rain < 30 {
            for p in [root-->[?:Person]] { p.warning=""; p.last_relay=""; }
            c.warnings_at=-1; disengage;
        }
        if c.warnings_at < 0 { c.warnings_at=c.minute; }
        visit [root-->[?:Person, role=="ward_officer"]];
    }
    can relay with Person entry {
        if here.warning { disengage; }
        area=area_for(here); if area is None { disengage; }
        try { here.warning=personalised_warning(here.name,here.role,here.language,area.name,area.risk,area.eta,route_for(area)); }
        except Exception { here.warning=template_warning(here,area); }
        here.last_relay="Warning relayed";
        visit [here->:Trusts:->[?:Person]];
    }
}
walker SilenceEscalator {
    has after_minutes: int = 10;
    can begin with Root entry {
        c=control(); c.minute=c.minute+self.after_minutes;
        for p in [root-->[?:Person]] { if p.warning and not p.acknowledged and p.vulnerability>=4 and not p.needs_visit { visit p; } }
    }
    can escalate with Person entry {
        if here.needs_visit { disengage; }
        contacts=[here<-:Trusts:<-[?:Person]];
        if contacts {
            best=contacts[0]; best_weight=0;
            for contact in contacts {
                for edge in [edge contact ->:Trusts:-> here] { if edge.weight > best_weight { best=contact; best_weight=edge.weight; } }
            }
            here.needs_visit=True; here.last_relay="Visit requested: "+best.name;
            control().escalations=control().escalations+1;
        }
    }
}
walker ReportVerifier {
    has target: Report | None = None, upstream_risk: int = 0, upstream_reports: int = 0;
    can begin with Root entry { if self.target { visit self.target; } }
    can inspect_report with Report entry { visit [here->:ReportedAt:->[?:Area]]; }
    can inspect_area with Area entry {
        self.upstream_risk=here.risk;
        for upstream in [here<-:FlowsTo:<-[?:Area]] { self.upstream_risk=max(self.upstream_risk,upstream.risk); self.upstream_reports=self.upstream_reports+len([upstream<-:ReportedAt:<-[?:Report]]); }
        r=self.target; if r is None { disengage; }
        if self.upstream_risk>=55 or self.upstream_reports>=1 { r.status="confirmed"; here.boost=here.boost+12; control().verified_at=control().minute; if control().first_ack<0 { control().first_ack=control().minute; } }
        elif self.upstream_risk>=35 { r.status="plausible"; here.boost=here.boost+5; }
        else { r.status="unverified"; }
        try { r.reasoning=verification_reason(r.text,here.name,self.upstream_risk,self.upstream_reports); }
        except Exception { r.reasoning=r.status+": "+here.name+" risk is "+str(self.upstream_risk)+"% with "+str(self.upstream_reports)+" upstream corroborating reports."; }
    }
}
def:pub run_rainfall(rain: int) -> DashboardState { seed_sample_data(); root spawn RiskPropagator(rain=max(0,min(100,rain))); root spawn WarningRelay(); return snapshot(); }
def:pub acknowledge(name: str) -> DashboardState {
    seed_sample_data(); c=control(); p=person_by_name(name);
    if p { c.minute=c.minute+2; p.acknowledged=True; p.needs_visit=False; p.last_relay="Acknowledged safe"; if c.first_ack<0 and c.warnings_at>=0 { c.first_ack=c.minute; } }
    return snapshot();
}
def:pub fast_forward(tick: int) -> DashboardState { seed_sample_data(); c=control(); c.minute=c.minute+10; root spawn SilenceEscalator(after_minutes=0); return snapshot(); }
def:pub submit_report(author: str, area_name: str, text: str) -> DashboardState {
    seed_sample_data(); c=control(); c.minute=c.minute+2; area=area_by_name(area_name);
    if area and text.strip() { r=Report(text=text,author=author,minute=c.minute); root ++> r; r +>:ReportedAt():+> area; root spawn ReportVerifier(target=r); }
    return snapshot();
}
def:pub confirm_visit(name: str) -> DashboardState {
    seed_sample_data(); c=control(); c.minute=c.minute+2; p=person_by_name(name);
    if p { p.needs_visit=False; p.acknowledged=True; p.last_relay="Visit confirmed by "+name; }
    return snapshot();
}
def:pub reset_demo(tick: int) -> DashboardState {
    seed_sample_data(); c=control(); c.rain=0; c.minute=0; c.escalations=0; c.first_ack=-1; c.verified_at=-1; c.warnings_at=-1;
    for p in [root-->[?:Person]] { p.warning=""; p.acknowledged=False; p.needs_visit=False; p.last_relay=""; }
    for a in [root-->[?:Area]] { a.risk=8; a.eta=180; a.trend="watch"; a.boost=0; for road in [a->:Connects:->[?:Road]] { road.status="open"; } }
    for r in [root-->[?:Report]] { del r; }
    return snapshot();
}
def:pub ussd(text: str) -> str {
    seed_sample_data(); parts=text.strip().split("|"); command=parts[0].upper();
    if command=="ACK" and len(parts)>=2 { _=acknowledge(parts[1]); return "Asante "+parts[1]+". Marked safe."; }
    if command=="REPORT" and len(parts)>=3 { state=submit_report("USSD caller",parts[1],"|".join(parts[2:])); if state.reports { last=state.reports[len(state.reports)-1]; return "Report received: "+last.status+". "+last.reasoning; } return "Report received: unverified. Area or text was not valid."; }
    if command=="STATUS" and len(parts)>=2 { a=area_by_name(parts[1]); if a { return a.name+": "+a.trend+", risk "+str(a.risk)+"%, ~"+str(a.eta)+" min. Roads: "+route_for(a); } return "Area not found. Use a listed area name."; }
    return "Commands: ACK|<name>, REPORT|<area>|<text>, STATUS|<area>.";
}
def make_area_view(a: Area) -> AreaView { roads=[r.name+" · "+r.status for r in [a->:Connects:->[?:Road]]]; return AreaView(name=a.name,river=a.river,risk=a.risk,eta=a.eta,trend=a.trend,roads=", ".join(roads),boost=a.boost); }
def make_person_view(p: Person) -> PersonView { a=area_for(p); return PersonView(name=p.name,role=p.role,language=p.language,area=a.name if a else "",vulnerability=p.vulnerability,acknowledged=p.acknowledged,warning=p.warning,needs_visit=p.needs_visit,relay=p.last_relay); }
def snapshot -> DashboardState {
    seed_sample_data(); c=control(); areas=[make_area_view(a) for a in [root-->[?:Area]]]; areas.sort(key=lambda (a: AreaView) { (-a.risk,a.name); });
    people=[make_person_view(p) for p in [root-->[?:Person]]]; people.sort(key=lambda (p: PersonView) { p.name; }); reports: list[ReportView]=[];
    for r in [root-->[?:Report]] { a=[r->:ReportedAt:->[?:Area]]; reports.append(ReportView(text=r.text,area=a[0].name if a else "",author=r.author,status=r.status,reasoning=r.reasoning,minute=r.minute)); }
    reports.reverse(); trusts: list[TrustView]=[];
    for p in [root-->[?:Person]] { for t in [p->:Trusts:->[?:Person]] { for e in [edge p ->:Trusts:-> t] { trusts.append(TrustView(from_name=p.name,to_name=t.name,weight=e.weight)); } } }
    red=len([a for a in areas if a.risk>=70]); visits=len([p for p in people if p.needs_visit]); verified=len([r for r in reports if r.status=="confirmed"]); brief="";
    try { brief=resource_brief(red,visits,verified); } except Exception { brief="Stage shelter, medic and boat resources near the highest-risk corridor; arrange "+str(visits)+" welfare visit(s)."; }
    return DashboardState(rain=c.rain,minute=c.minute,areas=areas,people=people,reports=reports,trusts=trusts,resource_brief=brief,escalations=c.escalations,first_ack=c.first_ack,verified_at=c.verified_at,warnings_at=c.warnings_at);
}
def:pub get_state(tick: int) -> DashboardState { return snapshot(); }
