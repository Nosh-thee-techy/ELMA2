
import from walkers { RiskPropagator, WarningRelay, SilenceEscalator, ReportVerifier, run_rainfall, acknowledge, fast_forward, submit_report, reset_demo, confirm_visit, ussd }
import from graph { seed_sample_data, control, Area, Person, Report, ReportedAt }

test "downstream risk rises and low rain clears warnings" {
    seed_sample_data(); _=run_rainfall(70);
    upstream=[root-->[?:Area,name=="Korogocho"]][0]; downstream=[root-->[?:Area,name=="Industrial Area"]][0];
    assert downstream.risk > upstream.risk;
    _=run_rainfall(0); resident=[root-->[?:Person,name=="Wanjiku"]][0]; assert resident.warning=="";
}
test "warning, acknowledgement clock, visit and reset work" {
    seed_sample_data(); _=run_rainfall(70); c=control(); assert c.warnings_at>=0;
    _=acknowledge("Kip"); assert c.minute==2; assert c.first_ack==2;
    _=fast_forward(0); kamau=[root-->[?:Person,name=="Mzee Kamau"]][0]; assert kamau.needs_visit;
    _=confirm_visit("Mzee Kamau"); assert kamau.acknowledged and not kamau.needs_visit;
    _=reset_demo(0); assert control().minute==0 and control().rain==0;
}
test "report verification retains risk boost and USSD replies" {
    seed_sample_data(); _=run_rainfall(70); area=[root-->[?:Area,name=="Mukuru"]][0];
    _=submit_report("Wanjiku","Mukuru","Water at bridge"); assert len([root-->[?:Report]])==1;
    before=area.risk; _=run_rainfall(70); assert area.risk>=before;
    assert ussd("STATUS|Mukuru").startswith("Mukuru:");
    assert ussd("ACK|Kip")=="Asante Kip. Marked safe.";
}
