# Running Biomechanics Analyzer

# Dev/Creator-tubakhxn
A zero-configuration computer-vision pipeline that turns a plain video of a runner into a professional, sports-science style analysis video. The original project was a single file; this fork keeps that behavior and splits the code into a package.

The output is a side-by-side render:

- **Left panel** — the original footage with a glowing HUD-style cyan/orange pose skeleton overlaid on the runner (comet trails on the legs, foot-strike shockwave pulses, HUD tracking brackets).
- **Right panel** — a dark analytics dashboard showing:
  - **Cadence** (steps per minute) with a live ring gauge
  - **Cadence-over-time** area graph
  - **Average knee shape at foot strike**, with an angle arc and mean ± std knee angle
  - **Ankle path visualization** (looping stride trace for each foot)
  - **Symmetry**, **Stability**, and **Speed** mini ring-gauges (speed via optional treadmill-display OCR)

No manual joint clicking, no config file, no browser UI — everything is detected and computed automatically from the input video using [MediaPipe Pose](https://developers.google.com/mediapipe/solutions/vision/pose_landmarker).

The command below is `python main.py`. Upstream docs say `running_biomechanics_analyzer.py`; that filename is not the entry point in this tree. See `docs/ARCHITECTURE.md` for the pipeline.

## Original vs added in this fork

### Original (Tuba Khan, [@tubakhxn](https://github.com/tubakhxn))

Pose detection, primary-runner selection, One Euro smoothing, foot-strike cadence, knee shape, symmetry, stability, treadmill OCR, HUD and dashboard drawing, and audio mux. MIT License — see `LICENSE`. Please keep this credit if you reuse the project.

### Added by me

- **Phase 0.** Split the original single file into the `analyzer` package (`pose`, `filters`, `events`, `metrics`, `render`, plus `calibration` and `preprocess`) and a thin `main.py`. The video pipeline is the same: `input.mp4` still produces `input_analyzed.mp4`.
- **Phase 1.** Pixel-to-meter scale from `--height-cm`, stride and step length, ground-contact and flight time (toe-off added in `events.py`), trunk lean, hip vertical oscillation, overstride, and `--csv` export. Without a height, meter-based values stay unavailable.
- **Phase 2.** Optional `--preprocess` stages: CLAHE on the luminance channel, feature-based stabilization (only when the camera is moving), and bilateral denoising. `nlmeans` is available and much slower. `benchmark_preprocess.py` times each combination and, when MediaPipe is installed, records pose detection rate and landmark jitter.
- **Phase 3.** Lucas-Kanade tracking of the ankles, separate from the pose landmarks. Foot strikes from that track are compared with the landmark detector. The summary reports the mean absolute timing difference in milliseconds.
- **Phase 4.** `label_strikes.py` marks foot strikes into JSON. `evaluate.py` scores precision, recall, and F1 within ±2 frames, plus cadence error. `--synthetic` compares baseline, CLAHE, stabilization, and both on generated clips. MediaPipe lite / full / heavy are scored when the package is installed and you add your own labeled clips under `data/labels`.

---

## Features

- Automatic pose detection and primary-runner selection (works even with multiple people in frame)
- One Euro Filter–based landmark smoothing to kill jitter without adding lag
- Foot-strike detection from ankle/hip oscillation, with physiologically-plausible cadence bounds
- Exponentially-averaged knee shape accumulation at each strike
- Savitzky-Golay smoothed ankle path traces
- Optional OCR-based treadmill speed reading (`easyocr`)
- Automatic audio muxing back onto the output video (via `ffmpeg`, if available)
- Auto-downloads the required MediaPipe pose model on first run

---

## Requirements

- Python 3.9+
- `ffmpeg` / `ffprobe` on your `PATH` (optional, for keeping the original audio track)

Python dependencies are listed in `requirements.txt`:

```
opencv-python
mediapipe
numpy
scipy
pillow
matplotlib
```

`easyocr` is optional and commented out in `requirements.txt`. It is only used for reading a treadmill's on-screen speed display. If it isn't installed, the script still runs and the SPEED gauge shows `UNAVAILABLE`. `matplotlib` is used by `evaluate.py` to write the result plots. The unit tests do not need MediaPipe.

---

## Installation

The original project:

```bash
git clone https://github.com/tubakhxn/running-biomechanics-analyzer.git
cd running-biomechanics-analyzer
pip install -r requirements.txt
```

This fork is the `Running-Biomechanics-Analyzer` folder. From that folder:

```bash
pip install -r requirements.txt
python -m unittest discover -s tests -t .
python main.py input.mp4
```

---

## Usage

```bash
python main.py
python main.py input.mp4
```

With no path, the project uses the bundled clip `demo/run.mp4` and writes `demo/run_analyzed.mp4`. A path of your own still writes `input_analyzed.mp4` next to that file.

Open the same demo in a browser:

```bash
streamlit run app.py
```

Then go to [http://localhost:8501](http://localhost:8501).

### Options

| Flag | Description | Default |
|---|---|---|
| `-o`, `--output` | Custom output path | `<input>_analyzed.mp4` |
| `--model {lite,full,heavy}` | Pose model accuracy/speed tradeoff | `full` |
| `--num-poses N` | Max people detected per frame before picking the primary runner | `3` |
| `--no-ocr` | Disable treadmill speed-display OCR | OCR enabled |
| `--height-cm` | Runner height in centimeters, for pixel-to-meter scale | unset (lengths unavailable) |
| `--csv PATH` | Per-frame CSV. Stride rows are written to `<name>_strides.csv` | no CSV |
| `--preprocess` | Comma-separated stages: `clahe`, `stabilize`, `denoise`, `nlmeans`. `all` is the first three | off |

Example:

```bash
python main.py my_run.mp4 -o analyzed_run.mp4 --model heavy
python main.py my_run.mp4 --height-cm 170 --csv my_run_metrics.csv
python main.py my_run.mp4 --preprocess clahe,stabilize
python benchmark_preprocess.py --synthetic
python benchmark_preprocess.py clip.mp4 --max-frames 120
python label_strikes.py data/clips/your_run.mp4
python evaluate.py --synthetic
```

`denoise` is a bilateral filter. `nlmeans` uses `fastNlMeansDenoisingColored`, which is much slower on full-resolution video, so it is left out of `--preprocess all` and out of the default benchmark.

To score a filmed run, put the file in `data/clips`, mark strikes with `label_strikes.py`, and run `python evaluate.py`. Label files whose names do not start with `synth_` are the ones compared across MediaPipe lite, full, and heavy.

---

## Demo

The clip below is the real HUD and dashboard on a synthetic side-view runner (height 170 cm). Pose detection is filled in with a known skeleton, because this copy was rendered without MediaPipe. Rebuild it with `python make_demo_gif.py`.

![Analysis demo](docs/demo.gif)

---

## Results

`python evaluate.py --synthetic` scores the project's foot-strike detector on six 4-second clips. A hit is the same foot within ±2 frames of the labeled lowest-foot frame. Cadence error is the whole-clip step rate minus the labeled rate. The detector here tracks bright markers and then uses `FootStrikeCadence`. These rows are not MediaPipe scores. MediaPipe lite / full / heavy stay blank until a labeled real clip is added (`results/model_comparison.csv`).

On a clear clip the detector finds 11 of 11 strikes, and every strike is 3 frames late, so F1 at ±2 frames is 0. Cadence error is 0 (166.7 steps per minute). The delay comes from the One Euro filter on the strike signal (`min_cutoff` 1.4 Hz) applied to a same-foot cycle of 0.72 s.

| Clip | Baseline | CLAHE | Stabilization | Both |
|---|---|---|---|---|
| Clear | 11/11 strikes, F1 0, cadence error 0 | same | same | same |
| Camera shake | 11/11, F1 0, cadence error 0 | same | same | same |
| Low contrast | 0 strikes | 11/11, F1 0, cadence error 0 | 0 strikes | 11/11, F1 0, cadence error 0 |
| Low contrast + shake | 0 strikes | 11/11, F1 0, cadence error 0 | 0 strikes | 11/11, F1 0, cadence error 0 |
| Dark gradient | 0 strikes | 0 strikes | 0 strikes | 0 strikes |
| Small vertical amplitude | 10 strikes, F1 0.19, cadence error +0.3 spm | same as baseline | F1 0.10, cadence error +0.3 spm | same as stabilization |

CLAHE brings back markers whose contrast was crushed. It does not bring back the feet in the dark gradient: those ankle pixels move from about 131 to 139 and stay under the threshold of 160. Stabilization does not change a global camera shift, because the strike signal subtracts hip height from ankle height. On the small-amplitude clip, stabilization lowered F1 from 0.19 to 0.10.

![F1 by condition](results/f1_by_condition.png)

![Cadence error by condition](results/cadence_error_by_condition.png)

![Detections by condition](results/detections_by_condition.png)

The full table is `results/evaluation.csv`. A separate timing run on a tiny synthetic frame is in `results/preprocess_benchmark.csv` (detection rate is blank there, because MediaPipe was not installed when it was recorded).

---

## Tests

```bash
python -m unittest discover -s tests -t .
```

That is the standard-library runner. `.github/workflows/tests.yml` runs the same command on Ubuntu with OpenCV, NumPy, SciPy, Pillow, and matplotlib. It does not install MediaPipe.

---

## License

MIT. The copyright notice in `LICENSE` is **Copyright (c) 2026 Tuba Khan**. Keep that notice if you copy or share the project. Additions in this fork are under the same license.

---

## How it works (short version)

1. Each frame is run through MediaPipe's Pose Landmarker (video mode) to get 33 body landmarks.
2. If multiple people are detected, the one with the largest, most confident, most track-continuous bounding box is selected as the runner.
3. Landmarks are smoothed with a One Euro Filter, with a confidence-aware hold for brief occlusions.
4. Ankle-vs-hip vertical oscillation is analyzed to detect foot-strike events, which drive the cadence estimate.
5. Knee, ankle, and hip joint angles are computed each frame; the knee angle at each foot strike feeds a running average "knee shape."
6. All of this is rendered live into a dashboard panel next to a stylized HUD overlay on the original footage.

---

## Limits

- One camera. Angles are in the image plane, not anatomical joint angles.
- `--height-cm` treats the longest upright nose-to-ankle span as stature. A side view or a bent posture biases the meter scale. With no height, lengths stay unavailable.
- On a treadmill the feet barely travel across the frame, so horizontal stride length underestimates belt travel.
- Contact time comes from the ankle-hip signal, not from a force plate.
- The person who is tracked is the largest stable pose. Someone else in frame can take the track.
- OCR speed reads on-screen text. It is not a measured velocity.
- Foot-strike F1 at ±2 frames is sensitive to the One Euro delay described in Results. A constant delay still leaves cadence error near zero.
- Low light and flat contrast change whether the pose, or a marker, is found. CLAHE helps crushed contrast. It does not fix a foot that is dark because the whole lower frame is dim.

---

## Fork it / contribute

1. **Fork** this repository on GitHub (top-right "Fork" button).
2. **Clone your fork:**
   ```bash
   git clone https://github.com/<your-username>/running-biomechanics-analyzer.git
   cd running-biomechanics-analyzer
   ```
3. **Create a branch** for your change:
   ```bash
   git checkout -b feature/my-improvement
   ```
4. **Set up your environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate   # Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```
5. Make your changes, test on a sample running video, then commit:
   ```bash
   git add .
   git commit -m "Describe your change"
   git push origin feature/my-improvement
   ```
6. Open a **Pull Request** back to the original repository describing what you changed and why.

Ideas for contributions: additional metrics (stride length, ground contact time), a config file for the color palette, batch/folder processing, a lightweight web UI, or unit tests around the cadence/foot-strike detector.

---

## Relevant resources

- [MediaPipe Pose Landmarker documentation](https://developers.google.com/mediapipe/solutions/vision/pose_landmarker) — the pose detection model this project is built on
- [OpenCV documentation](https://docs.opencv.org/) — used for all video I/O and drawing
- [One Euro Filter (original paper)](https://cristal.univ-lille.fr/~casiez/1euro/) — the smoothing algorithm used for landmarks and metrics
- [Savitzky–Golay filter (SciPy docs)](https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.savgol_filter.html) — used to smooth the cadence graph and ankle path traces
- [EasyOCR](https://github.com/JaidedAI/EasyOCR) — optional OCR library used for treadmill speed reading
- [FFmpeg](https://ffmpeg.org/) — used to remux the original audio track onto the rendered output

---

## dev/creator = tubakhxn

Built by **Tuba Khan** ([@tubakhxn](https://github.com/tubakhxn)).

- GitHub: [github.com/tubakhxn](https://github.com/tubakhxn)
- LinkedIn: [linkedin.com/in/tubakhxn](https://www.linkedin.com/in/tubakhxn)
- Email: tubakhan.work@gmail.com

If you use or build on this project, a star on the repo and a credit back to `tubakhxn` is appreciated 🙌
