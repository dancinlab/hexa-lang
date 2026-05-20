#!/usr/bin/env python3
# _geant4_antiproton_al_sim.py — antiproton-on-Al Geant4 MC simulation.
#
# Internal helper for `geant4_verify.py`. The substrate calls this only
# when `geant4-config` OR `geant4_pybind` is available; otherwise it
# emits the install-gated skip record without touching this file.
#
# Geometry:
#   Thick Al block (5 cm × 5 cm × 50 cm) — 50 cm of Al ≈ 135 g/cm² mass
#   thickness, > 2× the CSDA range of a 200 MeV antiproton (PDG / NIST
#   PSTAR proton CSDA = 4.49 g/cm² in Al at 100 MeV, ~16.5 g/cm² at
#   200 MeV — antiproton z² = 1, mass identical, so same Bethe-Bloch
#   range modulo small Barkas correction).
# Beam:
#   Anti-proton (PDG -2212), monoenergetic KE, monodirectional +z,
#   incident at (0, 0, -25 cm) just outside the front face.
# Tally:
#   SteppingAction tracks the antiproton's last in-Al position; on
#   track stop (StopAndKill or annihilation), the z-coordinate of the
#   last in-Al step is the penetration depth for that event.
# Run:
#   Mean ± stdev of penetration depth across N primary events.
#
# Citations:
#   - Geant4 11.4.1 (CERN / KEK / SLAC) — geant4-pybind 0.1.3 wheel.
#   - PDG RPP 2024 §34 Passage of Particles through Matter.
#   - NIST PSTAR proton CSDA range tables (physics.nist.gov).
#
# Honesty (g3):
#   This file produces an MC stopping-distance number. The
#   `geant4_verify.py` adapter owns measurement_gate + absorbed +
#   scope_caveats; THIS file just runs the simulation and returns
#   numbers.

from __future__ import annotations

import math
import sys
import time
from typing import Any

from geant4_pybind import (  # type: ignore
    G4VERSION_NUMBER,
    G4Box,
    G4LogicalVolume,
    G4NistManager,
    G4ParticleGun,
    G4ParticleTable,
    G4PVPlacement,
    G4RunManager,
    G4RunManagerFactory,
    G4RunManagerType,
    G4ThreeVector,
    G4UserEventAction,
    G4UserRunAction,
    G4UserSteppingAction,
    G4VUserActionInitialization,
    G4VUserDetectorConstruction,
    G4VUserPrimaryGeneratorAction,
    cm,
    cm3,
    g,
    GeV,
    MeV,
    QBBC,
)


# --- Detector: a single 5 cm × 5 cm × 50 cm Al block centred at origin.
class AlBlockDetector(G4VUserDetectorConstruction):
    HALF_X = 2.5 * cm
    HALF_Y = 2.5 * cm
    HALF_Z = 25.0 * cm   # block is 50 cm thick along beam axis

    def __init__(self) -> None:
        super().__init__()
        self.logic_al = None

    def Construct(self):
        nist = G4NistManager.Instance()
        al = nist.FindOrBuildMaterial("G4_Al")
        vacuum = nist.FindOrBuildMaterial("G4_Galactic")

        # World: 10 cm × 10 cm × 200 cm vacuum (so the antiproton can
        # travel before the front face and any backscatter is recorded).
        sol_world = G4Box("World", 5 * cm, 5 * cm, 100 * cm)
        log_world = G4LogicalVolume(sol_world, vacuum, "World")
        phys_world = G4PVPlacement(
            None, G4ThreeVector(), log_world, "World",
            None, False, 0, True,
        )

        # Al block centred at origin.
        sol_al = G4Box("AlBlock", self.HALF_X, self.HALF_Y, self.HALF_Z)
        self.logic_al = G4LogicalVolume(sol_al, al, "AlBlock")
        G4PVPlacement(
            None, G4ThreeVector(0, 0, 0),
            self.logic_al, "AlBlock",
            log_world, False, 0, True,
        )

        return phys_world


# --- Primary generator: antiproton, +z, monoenergetic KE.
class AntiprotonBeam(G4VUserPrimaryGeneratorAction):
    def __init__(self, ke_mev: float) -> None:
        super().__init__()
        self.ke_mev = ke_mev
        self.gun = G4ParticleGun(1)
        pt = G4ParticleTable.GetParticleTable()
        pbar = pt.FindParticle("anti_proton")
        if pbar is None:
            raise RuntimeError(
                "G4ParticleTable returned None for anti_proton — "
                "FTFP_BERT/QBBC must define it; physics list mis-init?"
            )
        self.gun.SetParticleDefinition(pbar)
        self.gun.SetParticleMomentumDirection(G4ThreeVector(0, 0, 1))
        self.gun.SetParticleEnergy(ke_mev * MeV)
        # Start just outside the front face of the Al block.
        self.gun.SetParticlePosition(
            G4ThreeVector(0, 0, -(AlBlockDetector.HALF_Z + 1.0 * cm))
        )

    def GeneratePrimaries(self, anEvent):
        self.gun.GeneratePrimaryVertex(anEvent)


# --- Event-level state: capture per-event last-in-Al z-position of the
# primary antiproton track.
class EventRecord:
    __slots__ = ("last_z_cm", "saw_primary")

    def __init__(self) -> None:
        self.last_z_cm: float = math.nan
        self.saw_primary: bool = False


# --- Stepping action: when the primary antiproton steps inside the Al
# block, store the post-step z. The last such z when the track ends is
# the stopping depth.
class StoppingTracker(G4UserSteppingAction):
    def __init__(self, event_rec: EventRecord) -> None:
        super().__init__()
        self.event_rec = event_rec

    def UserSteppingAction(self, step):
        track = step.GetTrack()
        # Only the primary antiproton — Track ID 1, parent 0.
        if track.GetParentID() != 0:
            return
        if track.GetDefinition().GetParticleName() != "anti_proton":
            return

        post = step.GetPostStepPoint()
        touchable = post.GetTouchable()
        if touchable is None:
            return
        volume = touchable.GetVolume()
        if volume is None or volume.GetName() != "AlBlock":
            return

        # Capture post-step z in cm. Continually overwritten — the last
        # write IS the stopping point.
        self.event_rec.last_z_cm = post.GetPosition().z / cm
        self.event_rec.saw_primary = True


# --- Event action: at end-of-event, append the stopping depth to a
# run-wide buffer.
class EventBookkeeper(G4UserEventAction):
    def __init__(self, event_rec: EventRecord, depths_buf: list) -> None:
        super().__init__()
        self.event_rec = event_rec
        self.depths_buf = depths_buf

    def BeginOfEventAction(self, anEvent):
        self.event_rec.last_z_cm = math.nan
        self.event_rec.saw_primary = False

    def EndOfEventAction(self, anEvent):
        if not self.event_rec.saw_primary:
            return
        # Penetration depth = last_z - front_face. Front face is at
        # z = -HALF_Z in world frame.
        depth_cm = self.event_rec.last_z_cm - (-AlBlockDetector.HALF_Z / cm)
        self.depths_buf.append(depth_cm)


# --- Run action: prints a summary line for the operator.
class RunSummary(G4UserRunAction):
    def __init__(self, depths_buf: list) -> None:
        super().__init__()
        self.depths_buf = depths_buf

    def EndOfRunAction(self, aRun):
        if len(self.depths_buf) == 0:
            print("[g4-pbar] NO depths recorded (zero primary events?)")
            return
        n = len(self.depths_buf)
        mean = sum(self.depths_buf) / n
        var = sum((d - mean) ** 2 for d in self.depths_buf) / n
        std = math.sqrt(var)
        print(
            f"[g4-pbar] n={n} mean_depth={mean:.4f} cm  "
            f"stdev={std:.4f} cm"
        )


class ActionInit(G4VUserActionInitialization):
    def __init__(self, ke_mev: float, depths_buf: list) -> None:
        super().__init__()
        self.ke_mev = ke_mev
        self.depths_buf = depths_buf

    def Build(self):
        self.SetUserAction(AntiprotonBeam(self.ke_mev))
        self.SetUserAction(RunSummary(self.depths_buf))
        event_rec = EventRecord()
        self.SetUserAction(EventBookkeeper(event_rec, self.depths_buf))
        self.SetUserAction(StoppingTracker(event_rec))


def run_simulation(ke_mev: float, n_events: int) -> dict[str, Any]:
    """Run a Geant4 antiproton-on-Al simulation. Returns
    { ke_mev, n_events, depths_cm (list), mean_depth_cm, stdev_depth_cm,
      density_g_per_cm3, mean_depth_g_per_cm2, geant4_version,
      physics_list, wall_seconds }. Raises on any setup failure
    (silent success forbidden — g3).

    NB: Geant4 forbids re-creating G4RunManager in the same process.
    For multi-KE sweeps prefer `run_simulation_sweep` (one RunManager
    + many BeamOn calls); this entry-point spawns one process per call
    when used standalone."""
    return run_simulation_sweep([ke_mev], n_events)[0]


def run_simulation_sweep(
    ke_mev_list: list[float], n_events: int
) -> list[dict[str, Any]]:
    """Run a Geant4 antiproton-on-Al simulation sweep across multiple
    KE points within a single G4RunManager lifecycle. Returns a list
    of per-KE summary dicts in input order."""
    t0_outer = time.time()
    depths_buf: list[float] = []

    rm = G4RunManagerFactory.CreateRunManager(G4RunManagerType.Serial)
    detector = AlBlockDetector()
    rm.SetUserInitialization(detector)
    physics = QBBC()
    physics.SetVerboseLevel(0)
    rm.SetUserInitialization(physics)

    # Use a placeholder KE for first action init — we update the gun
    # energy between BeamOn calls via the primary-generator handle.
    init = ActionInit(ke_mev_list[0], depths_buf)
    rm.SetUserInitialization(init)
    rm.Initialize()

    primary = rm.GetUserPrimaryGeneratorAction()
    if primary is None:
        raise RuntimeError(
            "RunManager.GetUserPrimaryGeneratorAction() returned None "
            "— ActionInit.Build did not register the AntiprotonBeam."
        )

    density_g_per_cm3 = detector.logic_al.GetMaterial().GetDensity() / (g / cm3)
    results: list[dict[str, Any]] = []
    for ke_mev in ke_mev_list:
        t0 = time.time()
        depths_buf.clear()
        primary.gun.SetParticleEnergy(ke_mev * MeV)
        primary.ke_mev = ke_mev
        rm.BeamOn(n_events)
        if not depths_buf:
            raise RuntimeError(
                f"Geant4 BeamOn returned 0 recorded depths "
                f"(ke_mev={ke_mev}, n_events={n_events})"
            )
        n = len(depths_buf)
        mean = sum(depths_buf) / n
        var = sum((d - mean) ** 2 for d in depths_buf) / n
        std = math.sqrt(var)
        results.append({
            "ke_mev": ke_mev,
            "n_events": n_events,
            "n_recorded": n,
            "depths_cm": list(depths_buf),
            "mean_depth_cm": mean,
            "stdev_depth_cm": std,
            "density_g_per_cm3": density_g_per_cm3,
            "mean_depth_g_per_cm2": mean * density_g_per_cm3,
            "geant4_version_number": G4VERSION_NUMBER,
            "physics_list": "QBBC",
            "wall_seconds": time.time() - t0,
        })
    _ = t0_outer  # unused — per-KE wall_seconds is more useful
    return results

    if not depths_buf:
        raise RuntimeError(
            f"Geant4 BeamOn returned 0 recorded depths "
            f"(ke_mev={ke_mev}, n_events={n_events})"
        )

    n = len(depths_buf)
    mean = sum(depths_buf) / n
    var = sum((d - mean) ** 2 for d in depths_buf) / n
    std = math.sqrt(var)
    # G4_Al density in g/cm³ — dividing by (g/cm3) converts the internal
    # Geant4 unit to the numeric g/cm³ scalar.
    density_g_per_cm3 = detector.logic_al.GetMaterial().GetDensity() / (g / cm3)
    return {
        "ke_mev": ke_mev,
        "n_events": n_events,
        "n_recorded": n,
        "depths_cm": depths_buf,
        "mean_depth_cm": mean,
        "stdev_depth_cm": std,
        "density_g_per_cm3": density_g_per_cm3,
        "mean_depth_g_per_cm2": mean * density_g_per_cm3,
        "geant4_version_number": G4VERSION_NUMBER,
        "physics_list": "QBBC",
        "wall_seconds": time.time() - t0,
    }


if __name__ == "__main__":
    # CLI: <ke_mev> <n_events>
    ke = float(sys.argv[1]) if len(sys.argv) > 1 else 100.0
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 100
    out = run_simulation(ke, n)
    print(
        f"DONE  ke_mev={out['ke_mev']}  n={out['n_recorded']}  "
        f"mean_depth_cm={out['mean_depth_cm']:.4f}  "
        f"mean_depth_g_per_cm2={out['mean_depth_g_per_cm2']:.4f}  "
        f"stdev_cm={out['stdev_depth_cm']:.4f}  "
        f"wall_s={out['wall_seconds']:.1f}"
    )
