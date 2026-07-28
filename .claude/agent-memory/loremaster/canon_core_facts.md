---
name: canon-core-facts
description: Settled Hand and Seal canon — 7 polities and their one mechanic each, 3 reigns with the regnal arithmetic worked out, named characters, seal dies
metadata:
  type: project
---

Settled canon as of 2026-07-28. Verify against [[canon-locations]] before use.

## Polities — 7 of a hard maximum 9
Each carries exactly one mechanical habit the player must hold in their head.

| polity | colour | device | succession | the one mechanic |
|---|---|---|---|---|
| The Crown of Aachen-Verd | #c9a227 | double eagle | elective, "seven electors" | imperial authority; dates from ACCESSION |
| The Margraviate of Thurn | #8c1c2b | lion rampant | male primogeniture | die defaced before witnesses the day its holder dies |
| The Free City of Marchfeld | #2f6b3f | three towers | elected council, 3-yr Burgomaster | seal belongs to the office, never dies |
| The Prince-Bishopric of Saint Wend | #5b3a8c | crossed keys | cathedral chapter election | church authority; dates from ELECTION |
| The Duchy of Ostmark | #2d4f8c | stag | partible among all sons | fractional titles; two valid claims to one mill |
| The County of Hallenstein | #3a3540 | wolf head | agnatic | no woman inherits and no claim passes through one |
| The Wends of the Nether March | #a5762e | knot ring | agreement of elders, unwritten | keeps NO seals; wax on a Wendish instrument is added |

## Reigns and the arithmetic
Regnal year 1 = the epoch year itself (`epoch + year - 1`).

- **Otbert II** — elected 1176, acceded 1178, crowned 1181, died 1204.
- **Aldric I** — elected 1201, acceded 1204, crowned 1206, died at Marchfeld 1215.
  So: 12 regnal years by accession, 15 by election, 10 by coronation. All correct.
- **Kunrad IV** — elected 1214, acceded 1215, crowned 1219, reigns. Present year
  **1221** = his 7th year by accession.

## Seal dies (matrices.json)
Imperial Chancery (1180–). Dietrich of Thurn **first** die 1194–1207, legend
`DIETRICVS MARCHIO TVRNENSIS`; **second** die 1207–1211, legend adds `DEI GRATIA`
(he took the style in 1207), broken at his death 1211. Marchfeld commune 1189–.
Wend Abbey (crozier, vesica) 1187–. Wend Chapter (crossed keys, vesica) 1198–.
Berthold of Ostmark 1209–. Ulrich of Hallenstein 1202–.

## Named characters
- **R.V.** — the previous notary at the third desk. Wrote the memorandum, the
  book marginalia, and three Register entries. See [[canon-rv-plot-seed]].
- **Liutger von Ahr** — Vice-Chancellor. Witnesses imperial writs; writes to the
  desk after a Kesselholt confirmation.
- **Wendelin** — Bishop of Saint Wend, granted Kesselholt. **Brother Anselm** —
  cellarer of Saint Wend's-in-the-Wood, an advocate, not a tutorial.
- **Dietrich** — late Margrave of Thurn, d. 1211. **Berthold** — Duke of Ostmark,
  four sons. **Ulrich** — Count of Hallenstein, "seals a great deal and reads
  very little of it."
- Petitioners: Wilhelm Ott and daughter Elsbeth (Marchfeld coopers, Küfergasse
  plot); Adelheid Vesser (widow, Grellwater mill, the forged restoration);
  Gero Kalt (Thurn serjeant); Emmerich Hove (imperial steward); Matthias Erken
  (imperial bailiff of the Nether March).
- Witnesses in circulation: Eckhard von Melle (marshal of Thurn), Hugo Wend,
  Aldebrand Stoss, Gerhoh Lamp, Reinmar Vogt (d. 1217), Adalbero, Meinhard,
  Gozwin, Rudolf Gern.

## The Kalendar of the Dead (`data/world/necrology.json`, settled 2026-07-28)
The Chancery keeps **no necrology of its own** — only a bound book of EXTRACTS
returned by the houses that do. Title *The Kalendar of the Dead*, subtitle "obits
returned to this Chancery, and by whom". Deliberately NOT "Book of Obits": that is
indistinguishable from BOOK OF MATRICES on a cover at desk distance.

Four returning hands, three silences. Every entry is dated in **its own roll's**
reckoning; `written_up_to_*` is regnal, so finding the edge costs an Almanac trip.

| roll id | hand | reckoning | written up to |
|---|---|---|---|
| `chapter_of_saint_wend` | Cathedral Chapter of Saint Wend | **election** | Kunrad IV 6 = 1219 |
| `chapel_at_thurnstadt` | The Margrave's chapel at Thurnstadt | accession | Kunrad IV 5 = 1219 |
| `city_book_of_marchfeld` | The city book of Marchfeld | accession | Kunrad IV 7 = 1221 |
| `chancery_household_book` | The Chancery's own household book | accession | Kunrad IV 7 = 1221 |

Silent: **Ostmark** (partible, four sons, four foundations, no single roll);
**Hallenstein** (keeps one, will not send it; R.V. wrote to Ulrich four times);
**Nether March** (no writing at all, extracts burnt at Lenz in '18).

Load-bearing obits: Reinmar Vogt d. Kunrad IV 3 = **1217** (same year as case_01's
charter — that anomaly must stay); Eckhard von Melle d. Aldric I 12 = **1215**
(alive for case_02 in 1213 and case_04 in 1210); Dietrich of Thurn d. Aldric I 8 =
**1211** (cross-checks `thurn_dietrich_ii.broken_year`); Adalbero d. Kunrad IV 5
**by election** = **1218** (alive for case_03 in 1214 — teaches the election roll).

Rules: matching is on `person_id`, never on name. **Absence from a roll is never
evidence of life.** Hugo Wend of Grellwater is in no roll at all and is the shipped
demonstration of that. Never add a roll for a silent polity without retiring a
silence and its reason.

## Events
- **1218** — fire burnt the lower town at Grellwater (destroyed Adelheid's
  original charter). **1218** — the archive at Lenz burnt, taking forty years of
  Nether March oath-rolls. Currently two separate fires in one year.
