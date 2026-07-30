#!/usr/bin/env python3
"""Validate data/ without launching Godot.

This is a second implementation of the rules in scripts/rules/, written from the
same spec and deliberately NOT sharing code with it. Running both against the
same content is how a data mistake gets caught: if the GDScript adjudicator and
this script disagree about a case, one of them has a bug and you find out in a
second rather than in a playtest.

    python tools/verify_content.py

Checks performed:
  * every JSON file parses
  * cross-references resolve (emperors, polities, matrices)
  * seal legends are length-compatible with the dies they claim
  * each static case's authored correct_verdict is what the rules produce
  * dynamic precedent cases react correctly to representative Register states
  * day manifests and fallback case references resolve
  * each case has all three outcomes and at least one arrival line

Exit code is nonzero if anything failed, so it can go in CI later.
"""

import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DATA = os.path.join(ROOT, "data")

WILDCARDS = "·.?*_"

CLEAN, NOTE, DEFECT, CONTESTED, FATAL = range(5)
SEV_NAME = {CLEAN: "clean", NOTE: "note", DEFECT: "defect",
            CONTESTED: "contested", FATAL: "fatal"}

problems = []
notes = []


def fail(msg):
    problems.append(msg)


def load(*parts):
    path = os.path.join(DATA, *parts)
    if not os.path.exists(path):
        fail("missing file: %s" % os.path.relpath(path, ROOT))
        return None
    with open(path, "r", encoding="utf-8") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError as e:
            fail("%s: JSON error line %d col %d: %s"
                 % (os.path.relpath(path, ROOT), e.lineno, e.colno, e.msg))
            return None


# ------------------------------------------------------------------ regnal

def epoch(reign, style):
    return {"election": reign["election_year"],
            "coronation": reign["coronation_year"]}.get(style, reign["accession_year"])


def to_absolute(reign, year, style):
    return epoch(reign, style) + year - 1


def max_regnal(reign, style, present):
    e = epoch(reign, style)
    if e <= 0:
        return 0
    last = reign["end_year"] if reign["end_year"] >= 0 else present
    return last - e + 1


def admissible(reign, year, style, present):
    if epoch(reign, style) <= 0 or year < 1:
        return False
    if year > max_regnal(reign, style, present):
        return False
    return to_absolute(reign, year, style) <= present


# -------------------------------------------------------------------- seal

def legend_compatible(worn, reference):
    a, b = worn.strip().upper(), reference.strip().upper()
    if len(a) != len(b):
        return False
    return all(c in WILDCARDS or c == b[i] for i, c in enumerate(a))


def hex_to_rgb(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def color_close(a, b, tol=0.17):
    return all(abs(x - y) < tol for x, y in zip(hex_to_rgb(a), hex_to_rgb(b)))


def mismatch_code(seal, candidates):
    """Which feature of the impression fails, against the closest die.

    This used to return a flat "seal_mismatch" — a code scripts/rules/
    seal_check.gd CANNOT EMIT. Its _mismatch_finding initialises `code` to that
    value and then overwrites it on every branch of an exhaustive if/elif/else,
    so the engine always reports device_mismatch, shape_mismatch, color_mismatch
    or legend_mismatch and never the generic one.

    Nothing caught it because no shipped case has a visually mismatching seal, so
    the two implementations have never both run this path. The first authored bad
    seal would have made verify_content.py report a spurious "the two
    implementations disagree" — and the convention is that when they disagree one
    of them has a bug, which would have sent the next session hunting in the
    engine. The bug was here.

    Mirrors the engine exactly: same scoring (device 2, shape 1, legend 3), same
    attribute precedence.
    """
    best, best_score = candidates[0], -1
    for m in candidates:
        s = 0
        if seal["device"] == m["device"]:
            s += 2
        if seal["shape"] == m["shape"]:
            s += 1
        if legend_compatible(seal["legend"], m["legend"]):
            s += 3
        if s > best_score:
            best_score, best = s, m
    if seal["device"] != best["device"]:
        return "device_mismatch"
    if seal["shape"] != best["shape"]:
        return "shape_mismatch"
    if not color_close(best["wax_color"], seal["wax_color"]):
        return "color_mismatch"
    return "legend_mismatch"


def seal_findings(charter, world, matrices, present):
    out = []
    seal = charter.get("seal")
    if not seal:
        return out

    polity = world["polities"].get(seal["claims_polity"])
    if polity and not polity.get("seals_used", True):
        return [(FATAL, "seal_where_none_used")]

    reign = world["reigns"].get(charter["date_emperor"])
    chancery = world["polities"][charter["drawn_by_polity"]].get(
        "dating_style", "accession")
    year = to_absolute(reign, charter["date_regnal_year"], chancery) if reign else None

    candidates = [m for m in matrices
                  if m["owner_name"].strip().lower()
                  == seal["claims_owner"].strip().lower()]
    if not candidates:
        return [(FATAL, "matrix_unknown")]

    visual = [m for m in candidates
              if m["device"] == seal["device"]
              and m["shape"] == seal["shape"]
              and color_close(m["wax_color"], seal["wax_color"])
              and legend_compatible(seal["legend"], m["legend"])]
    if not visual:
        return [(FATAL, mismatch_code(seal, candidates))]
    if year is None:
        return [(NOTE, "seal_date_unresolved")]

    live = [m for m in visual
            if m["cut_year"] <= year
            and (m["broken_year"] < 0 or year <= m["broken_year"])]
    if not live:
        out.append((FATAL, "matrix_not_live"))
        for m in candidates:
            if m is not visual[0] and m["cut_year"] > visual[0]["cut_year"]:
                out.append((NOTE, "superseded_legend"))
        return out

    if seal.get("wear", 0.0) > 0.14:
        out.append((NOTE, "wear_but_sound"))
    out.append((CLEAN, "seal_sound"))
    return out


# -------------------------------------------------------------------- date

def date_findings(charter, world, present):
    out = []
    reign = world["reigns"].get(charter["date_emperor"])
    if reign is None:
        return [(DEFECT, "emperor_unknown")]
    style = world["polities"][charter["drawn_by_polity"]].get(
        "dating_style", "accession")
    if epoch(reign, style) <= 0:
        return [(DEFECT, "style_inapplicable")]
    year = charter["date_regnal_year"]
    if year < 1:
        return [(DEFECT, "date_absurd")]

    absolute = to_absolute(reign, year, style)
    if absolute > present:
        out.append((DEFECT, "date_in_future"))
    elif year > max_regnal(reign, style, present):
        out.append((DEFECT, "date_beyond_reign"))

    # Witnesses moved out to necrology_findings(); see scripts/rules/witness_check.gd.
    # Reading a man's death off the charter that names him meant a forger closed
    # the check by leaving one line out.

    if style != "accession":
        out.append((NOTE, "unusual_reckoning"))
    # Mirror of the guard in scripts/rules/date_check.gd. "The date reduces
    # cleanly" must be suppressed only when something is actually WRONG, not
    # merely when anything at all was said — hints live in the same list, and
    # gating on emptiness silences the CLEAN finding on exactly the two cases
    # where the arithmetic is the interesting part. That fix landed in GDScript
    # and never landed here, so the two implementations have been disagreeing
    # about the finding set on case_01 and case_03 ever since, and this tool
    # could not see it because main() only ever compared the final verdict.
    if not any(sev >= DEFECT for sev, _code in out):
        out.append((CLEAN, "date_sound"))
    return out


# ----------------------------------------------------------------- erasure

def erasure_findings(charter):
    """Has the skin been scraped since the wax went on?

    The only check here that convicts on the document's history rather than on
    its contents, which is why a forger who scrapes a year and writes a
    perfectly possible one is still caught.
    """
    out = []
    for e in charter.get("erasures", []):
        if e.get("innocent") or not e.get("dispositive", True):
            out.append((NOTE, "erasure_innocent"))
        elif not e.get("original_value"):
            out.append((DEFECT, "erasure_illegible"))
        else:
            out.append((FATAL, "erasure_dispositive"))
    return out


# --------------------------------------------------------------- necrology

def necrology_findings(charter, world, necrology, present):
    """Witness list against the rolls of the dead.

    Deliberately re-derived here rather than shared with the GDScript. The one
    invariant worth stating twice: absence from a roll NEVER produces a defect.
    A roll covers one house, stops at one year, and reckons in one style, and
    three of the seven polities return nothing at all.
    """
    out = []
    if necrology is None:
        return out
    reign = world["reigns"].get(charter["date_emperor"])
    if reign is None:
        return out
    style = world["polities"][charter["drawn_by_polity"]].get(
        "dating_style", "accession")
    if epoch(reign, style) <= 0 or charter["date_regnal_year"] < 1:
        return out
    year = to_absolute(reign, charter["date_regnal_year"], style)

    rolls = necrology.get("rolls", [])
    dead = 0
    unverifiable = 0
    silent = 0

    for w in charter.get("witnesses", []):
        house = w.get("house") or ""
        mine = [r for r in rolls if house and r.get("polity_id") == house]
        found = None
        found_roll = None
        for r in mine:
            for e in r.get("entries", []):
                if e.get("person_id") and e["person_id"] == w.get("person_id"):
                    found, found_roll = e, r
                    break
            if found:
                break

        if found is not None:
            dr = world["reigns"].get(found["died_emperor"])
            if dr is None:
                continue
            reckoning = found_roll.get("reckoning", "accession")
            if epoch(dr, reckoning) <= 0:
                continue
            died = to_absolute(dr, found["died_regnal_year"], reckoning)
            if died < year:
                dead += 1
                out.append((DEFECT, "witness_dead"))
            elif died == year:
                out.append((NOTE, "witness_died_that_year"))
            else:
                out.append((CLEAN, "witness_alive_by_roll"))
            # The parchment's own annotation, cross-examined against the roll.
            if w.get("died_emperor") and w.get("died_regnal_year"):
                ar = world["reigns"].get(w["died_emperor"])
                astyle = w.get("died_dating_style", "accession")
                if ar is not None and epoch(ar, astyle) > 0:
                    claimed = to_absolute(ar, w["died_regnal_year"], astyle)
                    if claimed != died:
                        out.append((DEFECT, "annotation_disagrees"))
            continue

        covered = False
        for r in mine:
            wr = world["reigns"].get(r.get("written_up_to_emperor"))
            if wr is None:
                continue
            edge = to_absolute(wr, r.get("written_up_to_regnal_year", 0),
                               r.get("reckoning", "accession"))
            if edge >= year:
                covered = True
                break
        if covered:
            silent += 1
        else:
            unverifiable += 1

    if dead >= 2:
        out.append((FATAL, "witness_list_impossible"))
    if unverifiable:
        out.append((NOTE, "necrology_incomplete"))
    if silent:
        out.append((CLEAN, "witness_roll_silent"))
    return out


# --------------------------------------------------------------- authority

def authority_findings(charter, world, present):
    reign = world["reigns"].get(charter["date_emperor"])
    if reign is None:
        return []
    chancery = world["polities"][charter["drawn_by_polity"]].get(
        "dating_style", "accession")
    styles = {"imperial": "accession", "church": "election"}
    drawing = world["polities"][charter["drawn_by_polity"]]
    if drawing.get("authority") == "custom":
        styles["custom"] = chancery
    verdicts = {}
    for auth, style in styles.items():
        if epoch(reign, style) <= 0:
            continue
        verdicts[auth] = "CONFIRM" if admissible(
            reign, charter["date_regnal_year"], style, present) else "DENY"
    if len(verdicts) < 2 or len(set(verdicts.values())) < 2:
        return []
    return [(CONTESTED, "reckoning_contested"), (NOTE, "which_authority")]


POLICY = [(FATAL, "DENY"), (CONTESTED, "REFER"), (DEFECT, "REFER")]


def adjudicate(charter, world, matrices, present):
    findings = (erasure_findings(charter)
                + seal_findings(charter, world, matrices, present)
                + date_findings(charter, world, present)
                + necrology_findings(charter, world, world.get("necrology"),
                                     present)
                + authority_findings(charter, world, present))
    for sev, verdict in POLICY:
        for f in findings:
            if f[0] == sev:
                return verdict, f[1], findings
    return "CONFIRM", "nothing_against", findings


def invert(verdict):
    return {"CONFIRM": "DENY", "DENY": "CONFIRM"}.get(verdict, verdict)


def precedent_positions(current, prior, world):
    """Independent mirror of PrecedentCheck's contest construction."""
    same = prior["claimant_id"] == current["claimant_id"]
    drawing = world["polities"][current["drawn_by_polity"]].get(
        "authority", "imperial")
    if same:
        if prior["verdict"] == "CONFIRM":
            return {}
        if current.get("supersedes_prior_instrument", False):
            return {}
        return {"office": prior["verdict"], drawing: "CONFIRM"}

    old_positions = prior.get("authority_verdicts", {})
    if old_positions:
        positions = {a: invert(v) for a, v in old_positions.items()}
        positions["office"] = invert(prior["verdict"])
        positions[drawing] = "CONFIRM"
        return positions
    if prior["verdict"] == "DENY":
        return {}
    return {"office": invert(prior["verdict"]), drawing: "CONFIRM"}


def procedural_with_precedent(current, prior, world, matrices, present):
    base, reason, findings = adjudicate(current, world, matrices, present)
    positions = precedent_positions(current, prior, world)
    if len(set(positions.values())) > 1 and not any(
            severity in (FATAL, DEFECT) for severity, _code in findings):
        return "REFER", "precedent_contested", positions
    return base, reason, positions


# ------------------------------------------------------------------- main

def main():
    world_raw = load("world", "world.json")
    matrices_raw = load("world", "matrices.json")
    order_raw = load("cases", "_order.json")
    if not (world_raw and matrices_raw and order_raw):
        report()
        return

    # What the GDScript rules actually derived, written by tests/test_rules.gd on
    # its last run. Absent is not a failure: this tool must stay runnable with no
    # Godot at all, which is the whole reason it is a separate implementation.
    # But when it IS there, every finding is compared, not only the verdict.
    gdscript_findings = {}
    derived_path = os.path.join(ROOT, ".tools", "derived_findings.json")
    if os.path.exists(derived_path):
        with open(derived_path, "r", encoding="utf-8") as f:
            try:
                gdscript_findings = json.load(f)
            except json.JSONDecodeError:
                notes.append("could not read .tools/derived_findings.json")
    else:
        notes.append("no .tools/derived_findings.json: run tests/test_rules.gd "
                     "to compare finding sets and not merely verdicts")

    necrology_raw = load("world", "necrology.json")
    world = {
        "reigns": {r["id"]: r for r in world_raw["reigns"]},
        "polities": {p["id"]: p for p in world_raw["polities"]},
        "necrology": necrology_raw,
    }
    matrices = matrices_raw["matrices"]
    present = world_raw["present_year"]

    # --- world sanity
    for r in world_raw["reigns"]:
        if not (r["election_year"] <= r["accession_year"] <= r["coronation_year"]):
            fail("reign '%s': election <= accession <= coronation does not hold"
                 % r["id"])
        if r["end_year"] >= 0 and r["end_year"] < r["accession_year"]:
            fail("reign '%s': ends before it starts" % r["id"])
    if len(world_raw["polities"]) > 9:
        fail("more than nine polities; learnability is the whole game")

    for m in matrices:
        if m["polity_id"] not in world["polities"]:
            fail("matrix '%s': unknown polity '%s'" % (m["id"], m["polity_id"]))
        if m["broken_year"] >= 0 and m["broken_year"] < m["cut_year"]:
            fail("matrix '%s': broken before it was cut" % m["id"])

    # --- necrology
    #
    # The rolls are the only source of law that lives outside the packet, so the
    # ways they can be wrong are different from everything else here: an entry
    # nobody can identify, a roll for a house that does not exist, a roll that
    # claims to be written up past the present day, or a polity that is both
    # silent and returning.
    if necrology_raw is not None:
        seen_person = {}
        silent_ids = {s.get("polity_id") for s in necrology_raw.get("silent", [])}
        for r in necrology_raw.get("rolls", []):
            if r.get("polity_id") not in world["polities"]:
                fail("necrology roll '%s': unknown polity '%s'"
                     % (r.get("id"), r.get("polity_id")))
            if r.get("polity_id") in silent_ids:
                fail("necrology roll '%s': its house is also listed as silent"
                     % r.get("id"))
            if r.get("reckoning") not in ("accession", "election"):
                fail("necrology roll '%s': reckoning must be accession or "
                     "election, not '%s'" % (r.get("id"), r.get("reckoning")))
            wr = world["reigns"].get(r.get("written_up_to_emperor"))
            if wr is None:
                fail("necrology roll '%s': unknown emperor '%s' in written_up_to"
                     % (r.get("id"), r.get("written_up_to_emperor")))
            else:
                edge = to_absolute(wr, r.get("written_up_to_regnal_year", 0),
                                   r.get("reckoning", "accession"))
                if edge > present:
                    fail("necrology roll '%s': written up to %d, which is after "
                         "the present year %d" % (r.get("id"), edge, present))
            for e in r.get("entries", []):
                pid = e.get("person_id")
                if not pid:
                    fail("necrology roll '%s': an entry has no person_id"
                         % r.get("id"))
                    continue
                if pid in seen_person:
                    fail("necrology: '%s' is entered in two rolls (%s and %s); "
                         "a man dies once" % (pid, seen_person[pid], r.get("id")))
                seen_person[pid] = r.get("id")
                dr = world["reigns"].get(e.get("died_emperor"))
                if dr is None:
                    fail("necrology entry '%s': unknown emperor '%s'"
                         % (pid, e.get("died_emperor")))
                    continue
                died = to_absolute(dr, e.get("died_regnal_year", 0),
                                   r.get("reckoning", "accession"))
                if died > present:
                    fail("necrology entry '%s': dies in %d, after the present "
                         "year %d" % (pid, died, present))
        # THE SILENT FAILURE THIS FILE EXISTS TO CATCH.
        #
        # Identity is matched on person_id and never on name, which is correct —
        # two men are called Hugo Wend. The cost is that a typo in an id does not
        # error: the man is simply never found, the roll reports itself silent,
        # and a witness who is supposed to be caught walks. That happened once
        # already between the case files and the rolls.
        #
        # A name that appears on both sides under two different ids is always a
        # mistake, and it is the one shape of this bug that can be detected.
        by_name = {}
        for r in necrology_raw.get("rolls", []):
            for e in r.get("entries", []):
                by_name.setdefault(e.get("name"), set()).add(e.get("person_id"))
        for case_file in order_raw["order"]:
            c = load("cases", case_file + ".json")
            if c is None:
                continue
            for doc in c.get("documents", []):
                for w in doc.get("witnesses", []):
                    ids = by_name.get(w.get("name"))
                    if ids and w.get("person_id") not in ids:
                        fail("case '%s': witness '%s' is person_id '%s', but the "
                             "rolls know that name as %s — one of them is a typo "
                             "and the man will never be found"
                             % (c["id"], w.get("name"), w.get("person_id"),
                                " or ".join(sorted(ids))))

        for s in necrology_raw.get("silent", []):
            if s.get("polity_id") not in world["polities"]:
                fail("necrology silence names unknown polity '%s'"
                     % s.get("polity_id"))
            if not s.get("reason"):
                fail("necrology silence for '%s' gives no reason; the player has "
                     "to be able to read WHY nothing comes from there"
                     % s.get("polity_id"))

    # --- books
    for book_file in sorted(os.listdir(os.path.join(DATA, "world", "books"))):
        if not book_file.endswith(".json"):
            continue
        b = load("world", "books", book_file)
        if b is None:
            continue
        for p in b.get("pages", []):
            if p.get("kind") == "matrix":
                if not any(m["id"] == p.get("matrix_id") for m in matrices):
                    fail("%s: page names unknown matrix '%s'"
                         % (book_file, p.get("matrix_id")))
            if p.get("kind") == "plate" and p.get("polity_id") not in world["polities"]:
                fail("%s: page names unknown polity '%s'"
                     % (book_file, p.get("polity_id")))

    load("world", "register_seed.json")

    check_encodings()

    # --- cases
    cases_by_id = {}
    print("Present year: %d\n" % present)
    for case_id in order_raw["order"]:
        c = load("cases", case_id + ".json")
        if c is None:
            continue
        cases_by_id[case_id] = c
        charters = [d for d in c["documents"] if d["kind"] == "charter"]
        if not charters:
            fail("case '%s': no charter" % case_id)
            continue
        ch = charters[0]
        if not ch.get("subject_id") or not ch.get("claimant_id"):
            fail("case '%s': charter lacks stable subject_id/claimant_id" % case_id)

        for key, table in (("date_emperor", world["reigns"]),
                           ("drawn_by_polity", world["polities"])):
            if ch[key] not in table:
                fail("case '%s': unknown %s '%s'" % (case_id, key, ch[key]))

        verdicts = {o["verdict"] for o in c.get("outcomes", [])}
        for v in ("CONFIRM", "DENY", "REFER"):
            if v not in verdicts:
                fail("case '%s': no outcome for %s" % (case_id, v))
        if not any(l.get("beat", "arrival") == "arrival" and not l.get("requires_case")
                   for l in c.get("lines", [])):
            fail("case '%s': no unconditional arrival line" % case_id)

        derived, reason, findings = adjudicate(ch, world, matrices, present)
        authored = c["correct_verdict"]
        dynamic = bool(c.get("dynamic_precedent", False))

        reign = world["reigns"][ch["date_emperor"]]
        chancery = world["polities"][ch["drawn_by_polity"]]["dating_style"]
        years = {s: to_absolute(reign, ch["date_regnal_year"], s)
                 for s in ("accession", "election", "coronation")}

        ok = dynamic or derived == authored
        print("%s  %s" % ("PASS" if ok else "FAIL", case_id))
        if dynamic:
            print("     authored DYNAMIC  baseline %-8s (%s)" % (derived, reason))
        else:
            print("     authored %-8s derived %-8s (%s)" % (authored, derived, reason))
        print("     %s yr %d, drawn by %s (%s)  ->  acc %d / elec %d / coron %d"
              % (reign["name"], ch["date_regnal_year"],
                 ch["drawn_by_polity"], chancery,
                 years["accession"], years["election"], years["coronation"]))
        print("     findings: %s" % ", ".join(
            "%s:%s" % (SEV_NAME[s], code) for s, code in findings))
        positions = authority_positions(ch, world, present)
        if positions and len(set(positions.values())) > 1:
            defensible = sorted(set(positions.values()) | {"REFER"})
            print("     positions: %s; defensible: %s" % (
                ", ".join("%s=%s" % item for item in positions.items()),
                ", ".join(defensible)))
        if not ok:
            fail("case '%s': authored %s but the documents produce %s"
                 % (case_id, authored, derived))

        # THE ACTUAL POINT OF THIS FILE.
        #
        # Two independently written implementations of the same rules are only
        # worth having if their outputs are compared, and until now the only
        # compared output was a three-valued verdict — a summary of a dozen
        # findings. A CLEAN that should have been a NOTE, a missing witness
        # finding masked by a FATAL, an extra defect underneath a fatality: all
        # of them agree on the verdict by luck, and the tool said PASS. That is
        # precisely how the date_sound guard drifted between the two for months
        # without either noticing.
        #
        # tests/test_rules.gd now writes what the GDScript actually derived.
        # Compare the whole list, in order.
        mine = ["%s:%s" % (SEV_NAME[s], code) for s, code in findings]
        theirs = gdscript_findings.get(case_id)
        if theirs is None:
            if gdscript_findings:
                fail("case '%s': the GDScript produced no finding list; the two "
                     "implementations cannot be compared" % case_id)
        elif theirs != mine:
            fail("case '%s': the two implementations disagree about the "
                 "findings.\n      godot : %s\n      python: %s"
                 % (case_id, ", ".join(theirs), ", ".join(mine)))

        seal = ch.get("seal")
        if seal:
            owned = [m for m in matrices
                     if m["owner_name"].strip().lower()
                     == seal["claims_owner"].strip().lower()]
            if not owned:
                notes.append("case '%s': seal claims '%s', which is in no die "
                             "record (intentional only if this is the puzzle)"
                             % (case_id, seal["claims_owner"]))
            for m in owned:
                if len(seal["legend"]) != len(m["legend"]):
                    notes.append("case '%s': legend length %d vs die '%s' length %d"
                                 % (case_id, len(seal["legend"]), m["id"],
                                    len(m["legend"])))
        print()

    verify_days(cases_by_id)
    verify_precedent(cases_by_id, world, matrices, present)

    report()


def authority_positions(charter, world, present):
    reign = world["reigns"].get(charter["date_emperor"])
    if reign is None:
        return {}
    chancery = world["polities"][charter["drawn_by_polity"]].get(
        "dating_style", "accession")
    styles = {"imperial": "accession", "church": "election"}
    if world["polities"][charter["drawn_by_polity"]].get("authority") == "custom":
        styles["custom"] = chancery
    verdicts = {}
    for auth, style in styles.items():
        if epoch(reign, style) > 0:
            verdicts[auth] = "CONFIRM" if admissible(
                reign, charter["date_regnal_year"], style, present) else "DENY"
    return verdicts


def verify_days(cases_by_id):
    manifest = load("days", "_order.json")
    if manifest is None:
        return
    for day_name in manifest.get("order", []):
        day = load("days", day_name + ".json")
        if day is None:
            continue
        if day.get("selection_mode") not in ("fixed", "tray"):
            fail("day '%s': invalid selection_mode" % day_name)
        for slot in day.get("case_slots", []):
            for key in ("case_id", "fallback_case_id", "requires_ruled",
                        "requires_unruled"):
                target = slot.get(key)
                if target and target not in cases_by_id:
                    fail("day '%s': unknown %s '%s'" % (day_name, key, target))
            # The two gates share one fallback and cannot both apply. Mirrored
            # from ContentLoader._validate on purpose: every rule in this file is
            # written twice, independently, so that when they disagree one of
            # them has a bug.
            if slot.get("requires_ruled") and slot.get("requires_unruled"):
                fail("day '%s': slot '%s' sets both requires_ruled and "
                     "requires_unruled" % (day_name, slot.get("case_id")))
            # A KEY THAT IS NOT PARSED IS SILENTLY IGNORED, on both sides. The
            # GDScript loader reads exactly four slot keys; anything else in the
            # JSON does nothing at all, with no error and no test failure. This
            # is the only place that notices.
            known = {"case_id", "fallback_case_id", "requires_ruled",
                     "requires_unruled"}
            for key in slot:
                if key.startswith("_") or key in known:
                    continue
                fail("day '%s': slot key '%s' is not parsed by ContentLoader "
                     "and does nothing" % (day_name, key))
        for opening in day.get("opening_documents", []):
            required = opening.get("requires_case")
            if required and required not in cases_by_id:
                fail("day '%s': opening letter requires unknown case '%s'"
                     % (day_name, required))


def verify_precedent(cases_by_id, world, matrices, present):
    needed = (
        "case_01_kufergasse", "case_02_grellwater",
        "case_03_kesselholt", "case_05_grellwater_regrant",
        "case_06_kesselholt_writ", "case_07_daughters_portion",
    )
    if not all(case_id in cases_by_id for case_id in needed):
        return
    charter = lambda case_id: next(
        d for d in cases_by_id[case_id]["documents"] if d["kind"] == "charter")

    grell = charter("case_02_grellwater")
    regrant = charter("case_05_grellwater_regrant")
    for prior_verdict, expected in (
            ("DENY", "CONFIRM"), ("CONFIRM", "REFER"), ("REFER", "REFER")):
        prior = {
            "verdict": prior_verdict,
            "claimant_id": grell["claimant_id"],
            "authority_verdicts": {},
        }
        got, _reason, _positions = procedural_with_precedent(
            regrant, prior, world, matrices, present)
        if got != expected:
            fail("Grellwater regrant after %s: got %s, wanted %s"
                 % (prior_verdict, got, expected))

    kessel = charter("case_03_kesselholt")
    writ = charter("case_06_kesselholt_writ")
    old_positions = authority_positions(kessel, world, present)
    for prior_verdict in ("CONFIRM", "DENY", "REFER"):
        prior = {
            "verdict": prior_verdict,
            "claimant_id": kessel["claimant_id"],
            "authority_verdicts": old_positions,
        }
        got, _reason, positions = procedural_with_precedent(
            writ, prior, world, matrices, present)
        if got != "REFER":
            fail("Kesselholt writ after %s: got %s, wanted REFER"
                 % (prior_verdict, got))
        if positions.get("imperial") != "CONFIRM" \
                or positions.get("church") != "DENY":
            fail("Kesselholt writ failed to invert stored authority positions")

    kufer = charter("case_01_kufergasse")
    portion = charter("case_07_daughters_portion")
    prior = {
        "verdict": "DENY",
        "claimant_id": kufer["claimant_id"],
        "authority_verdicts": {},
    }
    got, _reason, positions = procedural_with_precedent(
        portion, prior, world, matrices, present)
    if got != "CONFIRM" or positions:
        fail("superseding Küfergasse instrument did not cure the prior refusal")


def check_encodings():
    """Every text file: UTF-8, no BOM, LF, and no double-encoded characters.

    The last one is the nasty case. Rewriting a source file with a tool that
    round-trips through cp1252 turns every em dash into 'aEUR"' and nothing
    complains — Godot still runs, the diff looks enormous, and the damage only
    shows up when somebody opens the file on the other machine. It costs
    milliseconds to check and it has already happened once.
    """
    moji = [b"\xc3\xa2\xe2\x82\xac", b"\xc3\xa2\xc2\x80", b"\xc3\x82\xc2"]
    roots = ("scripts", "tests", "tools", "data", "scenes")
    checked = 0
    for root in roots:
        base = os.path.join(ROOT, root)
        if not os.path.isdir(base):
            continue
        for dirpath, _dirs, names in os.walk(base):
            for name in names:
                if not name.endswith((".gd", ".json", ".tres", ".tscn",
                                      ".py", ".cfg", ".md")):
                    continue
                path = os.path.join(dirpath, name)
                rel = os.path.relpath(path, ROOT).replace("\\", "/")
                raw = open(path, "rb").read()
                checked += 1
                if any(m in raw for m in moji):
                    fail("%s: double-encoded text (cp1252 round-trip damage)" % rel)
                if raw[:3] == b"\xef\xbb\xbf":
                    fail("%s: has a UTF-8 BOM" % rel)
                if b"\r\n" in raw:
                    fail("%s: has CRLF line endings" % rel)
                try:
                    raw.decode("utf-8")
                except UnicodeDecodeError as e:
                    fail("%s: not valid UTF-8 (%s)" % (rel, e))
    print("Encoding: %d text files checked.\n" % checked)


def report():
    for n in notes:
        print("note: %s" % n)
    if problems:
        print("\n%d PROBLEM(S):" % len(problems))
        for p in problems:
            print("  - %s" % p)
        sys.exit(1)
    print("All content checks passed.")


if __name__ == "__main__":
    main()
