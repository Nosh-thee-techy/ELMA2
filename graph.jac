# Wimbi's persistent graph: water, trust, and ground-truth reports.

sem personalised_warning = "Write a short, calm Nairobi flood warning. Match the person's role and language. Include a concrete action and never invent emergency contacts.";
def personalised_warning(name: str, role: str, language: str, area: str, risk: int, eta: int, route: str) -> str by llm();

sem verification_reason = "Give one factual one-line explanation for a flood report status using nearby risk and corroborating reports.";
def verification_reason(text: str, area: str, risk: int, neighbours: int) -> str by llm();

sem resource_brief = "Write a one-line, practical county flood response resource brief from the risk and escalation facts.";
def resource_brief(red_areas: int, visits: int, verified_reports: int) -> str by llm();

edge FlowsTo: Area --> Area {}
edge Connects: Area --> Road {}
edge Trusts: Person --> Person { has weight: int = 1; }
edge LocatedIn: Person --> Area {}
edge ReportedAt: Report --> Area {}
edge Feeds: River --> Area {}
edge Drains: DrainagePoint --> Area {}

node Area {
    has name: str = "", river: str = "", order: int = 0,
        risk: int = 8, eta: int = 180, trend: str = "watch";
}
node River { has name: str = "", rain_mm_hr: int = 0; }
node DrainagePoint { has name: str = "", condition: str = "clear"; }
node Road { has name: str = "", status: str = "open"; }
node Person {
    has name: str = "", role: str = "", language: str = "English",
        vulnerability: int = 0, acknowledged: bool = False,
        warning: str = "", needs_visit: bool = False, last_relay: str = "";
}
node Report {
    has text: str = "", author: str = "", status: str = "unverified",
        reasoning: str = "", minute: int = 0;
}
node Control {
    has rain: int = 0, minute: int = 0, escalations: int = 0,
        first_ack: int = 0, verified_at: int = 0;
}

obj AreaView {
    has name: str = "", river: str = "", risk: int = 0, eta: int = 0,
        trend: str = "", roads: str = "";
}
obj PersonView {
    has name: str = "", role: str = "", language: str = "", area: str = "",
        vulnerability: int = 0, acknowledged: bool = False, warning: str = "",
        needs_visit: bool = False, relay: str = "";
}
obj ReportView {
    has text: str = "", area: str = "", author: str = "", status: str = "",
        reasoning: str = "", minute: int = 0;
}
obj TrustView { has from_name: str = "", to_name: str = "", weight: int = 0; }
obj DashboardState {
    has rain: int = 0, minute: int = 0, areas: list[AreaView] = [],
        people: list[PersonView] = [], reports: list[ReportView] = [],
        trusts: list[TrustView] = [], resource_brief: str = "",
        escalations: int = 0, first_ack: int = 0, verified_at: int = 0;
}

def area_for(p: Person) -> Area | None {
    found = [p->:LocatedIn:->[?:Area]];
    return found[0] if found else None;
}

def person_by_name(wanted: str) -> Person | None {
    found = [root-->[?:Person, name==wanted]];
    return found[0] if found else None;
}

def area_by_name(wanted: str) -> Area | None {
    found = [root-->[?:Area, name==wanted]];
    return found[0] if found else None;
}

def template_warning(p: Person, area: Area) -> str {
    if p.role == "boda_rider" {
        return p.name + ": Epuka " + area.name + " low crossings. Tumia " + route_for(area) + "; flood ETA " + str(area.eta) + " min.";
    }
    if p.role == "tenant_ground_floor" {
        return p.name + ": Move documents, power leads and medicine above waist height now. Flood ETA " + str(area.eta) + " min.";
    }
    if p.role == "elderly_resident" {
        return p.name + ": Stay with a neighbour; Amina has been assigned to check on you. Keep phone charged.";
    }
    if p.language == "Sheng" {
        return p.name + ", maji iko juu " + area.name + ". Usingoje—move sasa, then check in.";
    }
    if p.language == "Swahili" {
        return p.name + ", tahadhari ya mafuriko " + area.name + ". Chukua vitu muhimu juu na uthibitishe uko salama.";
    }
    return p.name + ": Flood risk is rising in " + area.name + ". Move early, avoid low crossings, and check in.";
}

def route_for(area: Area) -> str {
    roads = [area->:Connects:->[?:Road]];
    return roads[0].name if roads else "the high route";
}

def seeded -> bool { return bool([root-->[?:River]]); }

def control -> Control {
    found = [root-->[?:Control]];
    if found { return found[0]; }
    fresh = Control(); root ++> fresh; return fresh;
}

def seed_sample_data {
    if seeded { return; }
    # Sample data — two river corridors and eight Nairobi areas.
    nairobi = River(name="Nairobi River"); ngong = River(name="Ngong River");
    korogocho = Area(name="Korogocho", river="Nairobi River", order=1);
    dondori = Area(name="Dandora", river="Nairobi River", order=2);
    mukuru = Area(name="Mukuru", river="Nairobi River", order=3);
    industrial = Area(name="Industrial Area", river="Nairobi River", order=4);
    kibera = Area(name="Kibera", river="Ngong River", order=1);
    langata = Area(name="Lang'ata", river="Ngong River", order=2);
    southc = Area(name="South C", river="Ngong River", order=3);
    westlands = Area(name="Westlands", river="Ngong River", order=4);
    bridge = DrainagePoint(name="Dandora bridge drain", condition="silted");
    roads = [Road(name="Outering Road"), Road(name="Mombasa Road"), Road(name="Ngong Road"), Road(name="Waiyaki Way")];
    root ++> nairobi; root ++> ngong; root ++> korogocho; root ++> dondori;
    root ++> mukuru; root ++> industrial; root ++> kibera; root ++> langata;
    root ++> southc; root ++> westlands; root ++> bridge;
    for road in roads { root ++> road; }
    nairobi +>:Feeds():+> korogocho; ngong +>:Feeds():+> kibera;
    korogocho +>:FlowsTo():+> dondori; dondori +>:FlowsTo():+> mukuru; mukuru +>:FlowsTo():+> industrial;
    kibera +>:FlowsTo():+> langata; langata +>:FlowsTo():+> southc; southc +>:FlowsTo():+> westlands;
    dondori +>:Connects():+> roads[0]; mukuru +>:Connects():+> roads[1]; langata +>:Connects():+> roads[2]; westlands +>:Connects():+> roads[3];
    bridge +>:Drains():+> dondori;
    people = [
        Person(name="Amina", role="ward_officer", language="Swahili", vulnerability=1),
        Person(name="Otieno", role="chama_leader", language="English", vulnerability=1),
        Person(name="Muthoni", role="mama_mboga", language="Swahili", vulnerability=2),
        Person(name="Kip", role="boda_rider", language="Sheng", vulnerability=2),
        Person(name="Wanjiku", role="tenant_ground_floor", language="Swahili", vulnerability=4),
        Person(name="Mzee Kamau", role="elderly_resident", language="Swahili", vulnerability=5),
        Person(name="Brian", role="landlord", language="English", vulnerability=2),
        Person(name="Nia", role="boda_rider", language="Sheng", vulnerability=2),
        Person(name="Salma", role="chama_leader", language="Swahili", vulnerability=2),
        Person(name="Joy", role="tenant_ground_floor", language="English", vulnerability=4),
        Person(name="Peter", role="mama_mboga", language="Swahili", vulnerability=2),
        Person(name="David", role="landlord", language="English", vulnerability=1)
    ];
    for p in people { root ++> p; }
    control();
    places = [korogocho, dondori, dondori, mukuru, mukuru, mukuru, industrial, kibera, kibera, langata, southc, westlands];
    for i in range(len(people)) { people[i] +>:LocatedIn():+> places[i]; }
    amina = people[0]; otieno = people[1]; muthoni = people[2]; kip = people[3]; wanjiku = people[4]; kamau = people[5]; brian = people[6]; nia = people[7]; salma = people[8]; joy = people[9]; peter = people[10]; david = people[11];
    amina +>:Trusts(weight=9):+> otieno; amina +>:Trusts(weight=8):+> salma; otieno +>:Trusts(weight=8):+> muthoni; otieno +>:Trusts(weight=9):+> kip; kip +>:Trusts(weight=8):+> wanjiku; muthoni +>:Trusts(weight=9):+> kamau; brian +>:Trusts(weight=6):+> wanjiku; salma +>:Trusts(weight=8):+> nia; salma +>:Trusts(weight=7):+> joy; nia +>:Trusts(weight=7):+> peter; david +>:Trusts(weight=6):+> joy;
}
