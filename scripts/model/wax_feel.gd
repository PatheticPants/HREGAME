class_name WaxFeel
extends Resource

## Every constant in the spoon-and-signet sequence. Same deal as PaperFeel: edit
## data/tuning/wax_feel.tres live while playing.
##
## The whole sequence still uses one verb — hold still — but now has a real
## material chain. Hold a brass spoon above the candle to soften a pigmented
## wax-and-resin cake, carry it while it is hot, hold it over the charter to
## pour, then hold the ring while the impression seats.

@export_group("Spoon — melting")
## How precisely the bowl must sit over the flame and how still the hand must be.
@export_range(10.0, 160.0, 1.0) var heat_radius: float = 54.0
@export_range(1.0, 200.0, 1.0) var heat_steady_speed: float = 42.0
## Seconds to bring a cold spoon to full heat.
@export_range(0.1, 6.0, 0.05) var heat_time: float = 1.35
## The tablet only starts slumping above this normalized temperature.
@export_range(0.0, 0.9, 0.01) var soften_temperature: float = 0.24
## Melt time after the softening point has been reached.
@export_range(0.1, 6.0, 0.05) var melt_time: float = 1.15
@export_range(0.2, 1.0, 0.01) var melt_ready: float = 0.82
## Time for a fully hot spoon to cool completely away from the flame.
@export_range(2.0, 30.0, 0.25) var carry_cool_time: float = 11.0
## Below this heat, the surface skins over and the spoon needs reheating.
@export_range(0.05, 0.95, 0.01) var pour_temperature: float = 0.42

@export_group("Spoon — pouring")
@export_range(1.0, 200.0, 1.0) var pour_steady_speed: float = 34.0
## Radius around the wax slot within which pouring is possible.
@export_range(20.0, 260.0, 1.0) var slot_radius: float = 82.0
## Seconds from level to full tilt, and back.
@export_range(0.05, 3.0, 0.01) var tilt_time: float = 0.55
@export_range(0.05, 3.0, 0.01) var untilt_time: float = 0.28
@export_range(4.0, 80.0, 0.5) var spoon_tilt_deg: float = 48.0
## Seconds between drops at full tilt.
@export_range(0.02, 1.2, 0.01) var drip_interval: float = 0.17

@export_group("Pool")
## Wax units per drop, and the amount considered a good pour. Below the low mark
## the impression comes out thin; above the high mark it blots and runs.
@export_range(0.02, 1.0, 0.01) var drop_volume: float = 0.135
@export_range(0.1, 2.0, 0.01) var good_low: float = 0.52
@export_range(0.1, 3.0, 0.01) var good_high: float = 1.06
@export_range(0.2, 4.0, 0.01) var blot_at: float = 1.30
## Radius in desk units at wax_amount == 1.
@export_range(10.0, 120.0, 0.5) var radius_at_unit: float = 46.0
## How fast the pool eases out to its target radius. Wax spreads *after* it lands.
@export_range(0.5, 20.0, 0.1) var spread_speed: float = 4.2
## Irregularity of the blob outline, 0 = a circle.
@export_range(0.0, 0.6, 0.01) var blob_jitter: float = 0.22
## Points around the rim. Below about thirty the silhouette reads as a polygon
## rather than as something that flowed, and the facets are very visible once a
## press deforms one side of it.
@export_range(6, 64, 1) var blob_points: int = 38
## Seconds before the wax is too cool to take an impression cleanly.
@export_range(1.0, 30.0, 0.1) var cool_time: float = 7.5

@export_group("Press — descent")
@export_range(20.0, 240.0, 1.0) var press_radius: float = 62.0
@export_range(1.0, 200.0, 1.0) var press_steady_speed: float = 30.0
## Seconds of steady holding to travel from first touch down to the resistance.
@export_range(0.05, 2.0, 0.01) var descend_time: float = 0.34

@export_group("Press — resistance")
## The moment that makes the press feel like pressing. Descent all but stops for
## this long before the wax gives. Tune by feel: too short and it is not felt at
## all, too long and it reads as a bug.
@export_range(0.0, 1.2, 0.01) var resistance_time: float = 0.30
## Fraction of normal descent speed during resistance. Not zero — it must creep,
## or the player thinks the input was dropped.
@export_range(0.0, 0.5, 0.005) var resistance_creep: float = 0.055
## Small upward push while resisting, so the ring visibly fights back.
@export_range(0.0, 8.0, 0.05) var resistance_shudder: float = 1.7

@export_group("Press — seat and hold")
## Seconds of holding after the give before the impression counts as fully seated.
@export_range(0.05, 2.0, 0.01) var seat_time: float = 0.30
@export_range(0.0, 1.0, 0.01) var shallow_below: float = 0.55
## Cursor movement during the press beyond which the impression smears.
@export_range(2.0, 80.0, 0.5) var smear_distance: float = 17.0

@export_group("Press — lift")
@export_range(0.05, 1.5, 0.01) var peel_time: float = 0.30
## How far the wax stretches after the ring before the string breaks.
@export_range(0.0, 40.0, 0.5) var peel_stretch: float = 13.0

@export_group("Randomisation")
## Ring rotation is jittered within this many degrees on every press, per the
## brief. Keep it small — the point is that no two impressions match, not that
## the ring is being thrown at the desk.
@export_range(0.0, 6.0, 0.1) var ring_jitter_deg: float = 2.0
@export_range(0.0, 0.4, 0.01) var opacity_jitter: float = 0.13
@export_range(0.0, 0.5, 0.01) var seat_time_jitter: float = 0.22
@export_range(0.0, 0.5, 0.01) var resistance_jitter: float = 0.30
