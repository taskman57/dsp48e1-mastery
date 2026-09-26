# DSP48E1 Mastery

High-throughput VHDL architectures leveraging AMD/Xilinx DSP48E1 primitives and time-division folding for minimal FPGA logic usage.

This repository demonstrates how silicon-level hardware design—using pre-adder symmetry, architectural folding, and precise pipeline alignment—can slash DSP slice consumption by up to 90% while closing setup timing on budget silicon.

---

## Repository Structure

```text
dsp48e1-mastery/
├── 01_folded_fir/                 # 50-tap 5x time-division folded FIR processing engine
│   ├── constraints/               # Timing and physical placement constraints (.xdc)
│   ├── hdl/                       # VHDL RTL sources (dsp_wrapper, fir_impl, range_detector)
│   ├── ipcores/                   # AMD/Xilinx IP core XCI definitions (clk_dsp, adc_fifo)
│   ├── sim/                       # Testbenches, golden ref vectors & verification scripts
│   ├── scripts/                   # Automated build & setup scripts
│   │   ├── fir_script.tcl         # Vivado Project Mode generation script
│   │   └── runme.bat              # One-click Windows batch project launcher
│   └── README.md                  # Detailed module hardware specification
├── 02_divider/                    # High-speed shift-subtract division engine (Planned)
└── 03_pattern_det/                # Pattern matching and auto-correlation engine (Planned)
```

---

## Quick Start & Project Generation

Each module includes an automated TCL script and Windows batch launcher to generate a complete Vivado **Project Mode** environment without manually adding files or setting up IP dependencies.

### Windows Batch Launcher
Navigate to the module's `scripts/` directory and execute `runme.bat`:

```cmd
cd 01_folded_fir\scripts
runme.bat
```

This batch script:
1. Sources the Xilinx toolchain environment via `settings64.bat`.
2. Automatically imports and synthesizes IP core dependencies (`clk_dsp`, `adc_fifo`) inside `ipcores/`.
3. Compiles VHDL design, simulation packages, and testbench sources.
4. Imports constraints from `constraints/` into `constrs_1`.
5. Sets the top-level design entity (`range_detector`) and testbench (`tb_range_detector`).
6. Prompts to open the generated project in the Vivado GUI.

---

## Target Modules & Features

### 1. Range Detector & Folded FIR Engine (`01_folded_fir`)
* **Dual Clock Domain Processing:** Converts input ADC sampling rate to a high-speed 250 MHz DSP processing clock via asynchronous CDC FIFO (`adc_fifo`).
* **5x Time-Division Folding:** Reduces a 50-tap symmetric FIR filter down to **5 DSP slices** running at 250 MHz (achieving an 80% DSP reduction over parallel symmetric engines).
* **Timing Closure:** Achieves clean setup timing closure with zero timing violations on Zynq-7000 (-1) silicon.
* **Golden Reference Verification:** Uses `rtl_golden_ref_vector.vhd` in simulation to validate hardware outputs against ideal model outputs.
* **Robust CDC & Reset Synchronization:** Incorporates `xpm_cdc_async_rst` for reset deassertion and `xpm_cdc_single` for output level classification flags.

### 2. High-Speed DSP Divider (`02_divider`)
* Hardware division via consecutive shift-subtract operations implemented directly inside cascaded DSP48E1 slices.

### 3. DSP Pattern Detector (`03_pattern_det`)
* Dedicated pattern matching and auto-correlation engine using built-in DSP slice comparator logic.

---

## Design Evolution (Module 1 Roadmap)

The FIR filter implementation progresses through four documented git commit milestones:

1. **Initial Parallel Baseline & Top Integration:** 54-tap symmetric FIR filter with top-level `range_detector` integration, dual-clock domains (250 MHz DSP clock), and async CDC FIFO buffering.
2. **50-Tap Scaling & Golden Reference:** Scaled to 50 taps to align mathematically with 5x time-division folding; integrated golden reference vector package.
3. **Time-Division Folding & Timing Closure (Completed):** Implemented 5x folding engine using 5 DSP slices running at 250 MHz with full timing closure and constraint integration.
4. **System Integration:** Dual-channel (I/Q) top-level integration feeding downstream processing blocks.

---

## Environment & Toolchain

* **Language:** VHDL
* **Synthesis & Simulation:** AMD Xilinx Vivado / ModelSim / Riviera-PRO
* **Target Device:** Zynq-7000 FPGA Family (`xc7z020clg400-1`)
* **Verification Environment:** GNU Octave / MathWorks MATLAB

---

## License

This project is licensed under the [MIT License](LICENSE).