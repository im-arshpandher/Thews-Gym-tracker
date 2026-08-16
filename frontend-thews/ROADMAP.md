# Thews — Feature Roadmap (Outperforming Strava & Hybrid Training Pro)

This document details the multi-phase technical roadmap for **Thews**, engineered to surpass traditional platforms like Strava by unifying outdoor endurance tracking with pro-level resistance training, local-first live segments, personal glowing route heatmaps, biometric cardiac decoupling, and 3D cinematic route visualization.

---

```mermaid
graph TD
    P1["Phase 1: Live Segments, Real-Time Ghost Racing & Personal Route Heatmaps"]
    P2["Phase 2: Grade-Adjusted Pace (GAP), Aerobic Decoupling & TRIMP Training Load"]
    P3["Phase 3: Real-Time Audio Coach, Voice Splits & Running Cadence Metronome"]
    P4["Phase 4: 3D Route Contour Flyover & High-Impact Social Reel Exporter"]
    P5["Phase 5: Hybrid Athlete Engine — Strength + Endurance Interference Optimizer"]

    P1 --> P2
    P2 --> P3
    P3 --> P4
    P4 --> P5

    subgraph Phase 1: Live Segments & Personal Heatmaps
        P1_1["All-Time Glowing GPS Route Heatmap Explorer"]
        P1_2["Local GPS Polygon Segment Detector"]
        P1_3["Real-Time Live Delta HUD (+2.4s Ahead of PR)"]
        P1_4["Interactive Route-to-Segment Creator"]
    end

    subgraph Phase 2: Pro Biomechanics & Training Load
        P2_1["Minetti Grade-Adjusted Pace (GAP) Engine"]
        P2_2["Aerobic Decoupling & Cardiac Drift Ratio"]
        P2_3["Bannister TRIMP & Acute-to-Chronic Workload Ratio"]
    end

    subgraph Phase 3: Hands-Free Voice Coaching
        P3_1["Customizable TTS Audio Split Announcer"]
        P3_2["Rhythmic Cadence Metronome (160-190 SPM)"]
        P3_3["Heart Rate Zone Target Voice Alerts"]
    end

    subgraph Phase 4: 3D Visualization & Reel Exporter
        P4_1["Interactive 3D Elevation Gradient Heatmap"]
        P4_2["Animated 60 FPS Route Flyover Generator"]
        P4_3["High-Contrast Social Story / Reel Snapshots"]
    end

    subgraph Phase 5: Hybrid Athlete Intelligence
        P5_1["Neuromuscular vs Aerobic Fatigue Cross-Index"]
        P5_2["Interference Effect Minimizer & Run Scheduling"]
        P5_3["Unified Strength + Cardio Readiness Score"]
    end
```

---

## Active & Upcoming Roadmap Phases

### Phase 1: Live Segments, Real-Time Ghost Racing & Personal Route Heatmaps
* **Goal:** Deliver an entirely offline, local-first segment racing and all-time glowing route heatmap experience superior to Strava's paywalled Live Segments & Personal Heatmap ($80/yr).
* **Technical Specifications:**
  * **Personal All-Time GPS Route Heatmap (`run_heatmap_screen.dart`):**
    * High-contrast Dark/Midnight basemap aggregating every recorded run, walk, and cycle in the local database.
    * Multi-pass glowing density renderer (`heatmap_polyline_painter.dart`) where repeatedly traversed streets and trails accumulate luminous electric volt / amber glow intensity.
    * Filterable by activity type (`jog, cycle`) and time window (`All Time`, `This Year`, `Last 30 Days`).
    * Explorer telemetry: Total territory distance, total elevation ascended, and exportable map territory snapshot.
  * **Local Segment Detection Engine:** Pre-compute bounding geo-boxes on GPX routes; trigger real-time audio and visual HUD notification upon crossing a segment start line.
  * **Real-time Live Ghost HUD:** Real-time distance and time delta comparison against personal record ($\Delta t = t_{\text{current}} - t_{\text{PR\_at\_distance}}$) with pulsing green/red pacing bar.
  * **Interactive Custom Segment Builder:** Select any segment of a past recorded run on the polyline map to instantly name and create a new local segment.
  * **Segment Leaderboards & Wind / Weather Tagging:** Track local personal history, PR crowns, and elevation profiles.
* **Target Dependencies:** `latlong2`, `flutter_map`, `drift`.
* **Key Target Files:**
  * `lib/features/running/presentation/run_heatmap_screen.dart`
  * `lib/features/running/presentation/widgets/heatmap_polyline_painter.dart`
  * `lib/features/running/domain/live_segment_engine.dart`
  * `lib/features/running/presentation/widgets/live_segment_hud.dart`
  * `lib/features/running/presentation/segment_builder_screen.dart`

---

### Phase 2: Grade-Adjusted Pace (GAP), Aerobic Decoupling & TRIMP Training Load
* **Goal:** State-of-the-art endurance physiology algorithms providing pro-grade telemetry without subscriptions.
* **Technical Specifications:**
  * **Minetti Grade-Adjusted Pace (GAP):** Real-time metabolic cost pace normalization using the Minetti polynomial equation based on instantaneous slope gradient $i = \frac{\Delta \text{elevation}}{\Delta \text{distance}}$:
    $$C_r(i) = 155.4 i^5 - 30.4 i^4 - 43.3 i^3 + 46.3 i^2 + 19.5 i + 3.6$$
    $$\text{GAP} = \text{Pace}_{\text{actual}} \times \frac{C_r(0)}{C_r(i)}$$
  * **Cardiac Drift & Aerobic Decoupling ($EF$):** Compare the Efficiency Factor ($EF = \frac{\text{Pace}}{\text{HR}}$) between the first half and second half of long runs to quantify aerobic endurance breakdown:
    $$\text{Decoupling Rate} = \frac{EF_{\text{half1}} - EF_{\text{half2}}}{EF_{\text{half1}}} \times 100\%$$
  * **Bannister TRIMP & Acute-to-Chronic Workload Ratio (ACWR):** Quantify cardiovascular training load stress scores ($TSS$) and overtraining/injury risk zones.
* **Target Dependencies:** `drift`, `fl_chart`.
* **Key Target Files:**
  * `lib/features/running/domain/gap_calculator.dart`
  * `lib/features/running/domain/aerobic_decoupling_engine.dart`
  * `lib/features/running/domain/trimp_workload_calculator.dart`

---

### Phase 3: Real-Time Audio Coach, Voice Splits & Running Cadence Metronome
* **Goal:** 100% hands-free running experience with intelligent audio feedback and cadence optimization.
* **Technical Specifications:**
  * **Customizable Audio Voice Announcer:** Text-to-speech voice splits announced into Bluetooth headphones every km, mile, or custom interval (current pace, split pace, average heart rate, distance remaining).
  * **Rhythmic Audio Cadence Metronome:** Built-in customizable rhythm generator (160–190 SPM) with subtle audio clicks or haptic pulses to train stride rate and reduce knee impact stress.
  * **Heart Rate Zone Audio Boundary Alerts:** Voice prompts when drifting outside target training zone (e.g. *"Exiting Zone 2 — Heart Rate 154 BPM, slow down pace"*).
* **Target Dependencies:** `flutter_tts`, `audioplayers` / native audio synthesizer.
* **Key Target Files:**
  * `lib/core/services/audio_coach_service.dart`
  * `lib/features/running/presentation/widgets/cadence_metronome_sheet.dart`

---

### Phase 4: 3D Route Contour Flyover & High-Impact Social Reel Exporter
* **Goal:** Visual superiority over Strava and Relive by generating stunning 3D elevation maps and animated video route reels.
* **Technical Specifications:**
  * **Interactive Elevation Gradient Heatmap:** Multi-color dynamic polyline on map reflecting gradient steepness (🟢 Flat $\to$ 🟡 Rolling $\to$ 🔴 Steep incline).
  * **Animated 60 FPS Route Flyover:** Render smoothed 3D route fly-through with moving athlete marker, dynamic pace graphs, and split achievement callouts.
  * **Pro Social Share Cards:** Exportable vertical 9:16 and square 1:1 image/video cards formatted for Instagram Stories, TikTok, and Strava with map snapshot, elevation profile, and biometrics.
* **Target Dependencies:** `flutter_map`, `screenshot`, `path_provider`, `share_plus`.
* **Key Target Files:**
  * `lib/features/running/presentation/widgets/gradient_route_painter.dart`
  * `lib/features/running/presentation/widgets/animated_run_flyover_view.dart`
  * `lib/features/running/presentation/widgets/pro_run_share_card.dart`

---

### Phase 5: Hybrid Athlete Engine — Strength + Endurance Interference Optimizer
* **Goal:** The ultimate competitive edge — the first app designed specifically for hybrid athletes who both lift heavy and run hard.
* **Technical Specifications:**
  * **Neuromuscular vs Aerobic Fatigue Matrix:** Unified dashboard combining weight room tonnage (squats, deadlifts) with running mileage and elevation.
  * **Interference Effect Minimizer:** Algorithmic schedule advisor optimizing the temporal spacing between heavy lower-body hypertrophy workouts and high-intensity running intervals to prevent mTOR/AMPK cellular signaling interference.
  * **Unified Athlete Readiness Score:** Comprehensive recovery score blending strength fatigue, running volume, sleep, and resting heart rate.
* **Target Dependencies:** `drift`, `riverpod`, `fl_chart`.
* **Key Target Files:**
  * `lib/features/hybrid/domain/interference_optimizer.dart`
  * `lib/features/hybrid/presentation/hybrid_dashboard_card.dart`
  * `lib/features/hybrid/domain/unified_athlete_readiness_engine.dart`

---

## Future Horizons & Long-Term Backlog

### Future Phase: Community, Async Challenges & Social Live Gym Battles
* **Status:** Saved for Future Exploration
* **Goal:** Connected fitness community with live ghost athlete running race overlays, synchronized gym rest timer battle lobbies, and community-verified routine marketplace.
* **Technical Specifications:**
  * **Ghost Athlete Race Overlay:** Render real-time ghost avatar on GPS run map representing a friend's past run or personal PR pacing.
  * **Live Gym Battle Rest Timer Lobbies:** Real-time WebRTC / WebSocket room synchronizing workout timers and live set counts among training partners.
  * **Verified Coach Routine Marketplace:** Share, rate, and fork structured workout routines with verified cryptographic 1RM proof cards.
* **Target Dependencies:** `web_socket_channel`, `qr_flutter`, `share_plus`.
* **Key Target Files:**
  * `lib/features/community/presentation/live_battle_lobby_screen.dart`
  * `lib/features/community/presentation/routine_marketplace_screen.dart`
  * `lib/features/community/domain/ghost_athlete_engine.dart`
