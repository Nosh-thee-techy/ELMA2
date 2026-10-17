import from graph { Area, Person, Report, seed_sample_data, control };
import from walkers { RiskPropagator, WarningRelay, SilenceEscalator, ReportVerifier };

test "rain reaches downstream areas and produces personalised fallback-safe alerts" {
    seed_sample_data();
    root spawn RiskPropagator(rain=18);
    root spawn WarningRelay();
    mukuru = [root-->[?:Area, name=="Mukuru"]][0];
    wanjiku = [root-->[?:Person, name=="Wanjiku"]][0];
    assert mukuru.risk >= 45;
    assert mukuru.eta < 180;
    assert wanjiku.warning != "";
}

test "silence creates a welfare-visit escalation and reports correct the local graph" {
    seed_sample_data();
    root spawn RiskPropagator(rain=20);
    root spawn WarningRelay();
    root spawn SilenceEscalator(after_minutes=10);
    kamau = [root-->[?:Person, name=="Mzee Kamau"]][0];
    assert kamau.needs_visit;
    area = [root-->[?:Area, name=="Mukuru"]][0];
    report = Report(text="Water at the bridge", author="Wanjiku", minute=control().minute);
    root ++> report; report +>:ReportedAt():+> area;
    before = area.risk;
    root spawn ReportVerifier(target=report);
    assert report.status == "confirmed";
    assert area.risk > before;
}
