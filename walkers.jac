import from graph { * };

# Walker 1: water moves downstream and changes Area risk/ETA in place.
walker RiskPropagator {
    has rain: int = 0, reports: list[str] = [];

    can begin with Root entry {
        seed_sample_data();
        control().rain = self.rain;
        for river in [root-->[?:River]] {
            river.rain_mm_hr = self.rain;
            visit river;
        }
    }

    can enter_river with River entry {
        visit [here->:Feeds:->[?:Area]];
    }

    can score_area with Area entry {
        river_factor = 5 if here.river == "Nairobi River" else 4;
        score = self.rain * river_factor - here.order * 9;
        if score < 5 { score = 5; }
        if score > 100 { score = 100; }
        here.risk = score;
        here.eta = max(12, 180 - score * 2 + here.order * 7);
        here.trend = "critical" if score >= 70 else "high" if score >= 45 else "watch";
        for road in [here->:Connects:->[?:Road]] {
            road.status = "avoid" if score >= 65 else "caution" if score >= 35 else "open";
        }
        self.reports.append(here.name + " " + str(here.risk));
        visit [here->:FlowsTo:->[?:Area]];
    }
}

# Walker 2: alerts leave the ward officer and fan out along weighted trust edges.
walker WarningRelay {
    has reports: list[str] = [];

    can begin with Root entry {
        seed_sample_data();
        visit [root-->[?:Person, role=="ward_officer"]];
    }

    can relay with Person entry {
        area = area_for(here);
        if area is None { disengage; }
        try {
            here.warning = personalised_warning(here.name, here.role, here.language, area.name, area.risk, area.eta, route_for(area));
        } except Exception {
            here.warning = template_warning(here, area);
        }
        here.last_relay = "ward relay";
        self.reports.append(here.name);
        visit [here->:Trusts:->[?:Person]];
    }
}

# Walker 3: after simulated time passes, the trusted neighbour is asked to visit.
walker SilenceEscalator {
    has after_minutes: int = 10, reports: list[str] = [];

    can begin with Root entry {
        c = control(); c.minute = c.minute + self.after_minutes;
        for p in [root-->[?:Person]] {
            if p.warning and not p.acknowledged and p.vulnerability >= 4 {
                visit p;
            }
        }
    }

    can escalate with Person entry {
        contacts = [here<-:Trusts:<-[?:Person]];
        if contacts {
            contacts.sort(key=lambda (p: Person) { p.vulnerability; });
            here.needs_visit = True;
            here.last_relay = "Visit requested: " + contacts[0].name;
            self.reports.append(here.name + " → " + contacts[0].name);
            control().escalations = control().escalations + 1;
        }
    }
}

# Walker 4: follows FlowTo edges upstream, combines local risk and reports, then feeds risk back.
walker ReportVerifier {
    has target: Report | None = None, upstream_risk: int = 0, upstream_reports: int = 0,
        reports: list[str] = [];

    can begin with Root entry {
        if self.target { visit self.target; }
    }

    can inspect_report with Report entry {
        visit [here->:ReportedAt:->[?:Area]];
    }

    can inspect_area with Area entry {
        self.upstream_risk = here.risk;
        for upstream in [here<-:FlowsTo:<-[?:Area]] {
            self.upstream_risk = max(self.upstream_risk, upstream.risk);
            self.upstream_reports = self.upstream_reports + len([upstream<-:ReportedAt:<-[?:Report]]);
        }
        reports_here = [here<-:ReportedAt:<-[?:Report, jid==self.report_id]];
        if not reports_here { disengage; }
        r = reports_here[0];
        if self.upstream_risk >= 55 or self.upstream_reports >= 1 {
            r.status = "confirmed";
            here.risk = min(100, here.risk + 12);
            here.eta = max(8, here.eta - 18);
            control().verified_at = control().minute;
        } elif self.upstream_risk >= 35 {
            r.status = "plausible";
            here.risk = min(100, here.risk + 5);
        } else { r.status = "unverified"; }
        try { r.reasoning = verification_reason(r.text, here.name, self.upstream_risk, self.upstream_reports); }
        except Exception { r.reasoning = r.status + ": " + here.name + " risk is " + str(self.upstream_risk) + "% with " + str(self.upstream_reports) + " upstream corroborating reports."; }
        self.reports.append(r.status);
    }
}

def:pub run_rainfall(rain: int) -> DashboardState {
    seed_sample_data();
    root spawn RiskPropagator(rain=rain);
    root spawn WarningRelay();
    return snapshot();
}

def:pub acknowledge(name: str) -> DashboardState {
    seed_sample_data();
    p = person_by_name(name);
    if p { p.acknowledged = True; if control().first_ack == 0 { control().first_ack = control().minute; } }
    return snapshot();
}

def:pub fast_forward -> DashboardState {
    seed_sample_data(); root spawn SilenceEscalator(after_minutes=10); return snapshot();
}

def:pub submit_report(author: str, area_name: str, text: str) -> DashboardState {
    seed_sample_data(); area = area_by_name(area_name);
    if area {
        r = Report(text=text, author=author, minute=control().minute); root ++> r; r +>:ReportedAt():+> area;
        root spawn ReportVerifier(target=r);
    }
    return snapshot();
}

def make_area_view(a: Area) -> AreaView {
    roads = [r.name + " · " + r.status for r in [a->:Connects:->[?:Road]]];
    return AreaView(name=a.name, river=a.river, risk=a.risk, eta=a.eta, trend=a.trend, roads=", ".join(roads));
}

def make_person_view(p: Person) -> PersonView {
    a = area_for(p);
    return PersonView(name=p.name, role=p.role, language=p.language, area=a.name if a else "", vulnerability=p.vulnerability, acknowledged=p.acknowledged, warning=p.warning, needs_visit=p.needs_visit, relay=p.last_relay);
}

def snapshot -> DashboardState {
    seed_sample_data(); c = control();
    areas = [make_area_view(a) for a in [root-->[?:Area]]]; areas.sort(key=lambda (a: AreaView) { (-a.risk, a.name); });
    people = [make_person_view(p) for p in [root-->[?:Person]]]; people.sort(key=lambda (p: PersonView) { p.name; });
    reports: list[ReportView] = [];
    for r in [root-->[?:Report]] {
        a = [r->:ReportedAt:->[?:Area]];
        reports.append(ReportView(text=r.text, area=a[0].name if a else "", author=r.author, status=r.status, reasoning=r.reasoning, minute=r.minute));
    }
    trusts: list[TrustView] = [];
    for p in [root-->[?:Person]] {
        for t in [p->:Trusts:->[?:Person]] { trusts.append(TrustView(from_name=p.name, to_name=t.name, weight=7)); }
    }
    red = len([a for a in areas if a.risk >= 70]); visits = len([p for p in people if p.needs_visit]); verified = len([r for r in reports if r.status == "confirmed"]);
    brief = "";
    try { brief = resource_brief(red, visits, verified); }
    except Exception { brief = "Stage " + str(max(1, red)) + " shelter point(s), " + str(visits) + " welfare visit(s), and one mobile medic near the highest-risk corridor."; }
    return DashboardState(rain=c.rain, minute=c.minute, areas=areas, people=people, reports=reports, trusts=trusts, resource_brief=brief, escalations=c.escalations, first_ack=c.first_ack, verified_at=c.verified_at);
}

def:pub get_state -> DashboardState { return snapshot(); }
