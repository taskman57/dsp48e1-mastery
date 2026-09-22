# DSP48E1 Mastery

High-throughput VHDL architectures leveraging AMD/Xilinx DSP48E1 primitives and time-division folding for minimal FPGA logic usage.

This repository demonstrates how silicon-level hardware design—using pre-adder symmetry, architectural folding, and precise pipeline alignment—can slash DSP slice consumption by up to 90% while closing setup timing on budget silicon.

---

## Repository Structure

```text
dsp48e1-mastery/
├── 01_folded_fir/                 # 54-tap / 50-tap folded symmetric FIR filter system
│   ├── hdl/                       # VHDL RTL source files, DSP wrappers & range detector
│   ├── ipcores/                   # AMD/Xilinx IP core XCI definitions (clk_dsp, adc_fifo)
│   ├── sim/                       # Testbenches & verification vectors
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
3. Compiles VHDL-2008 design and testbench sources.
4. Sets the top-level design entity (`range_detector`) and testbench (`tb_range_detector`).
5. Prompts to open the generated project in the Vivado GUI.

---

## Target Modules & Features

### 1. Range Detector & Folded FIR Engine (`01_folded_fir`)
* **Dual Clock Domain Processing:** Converts input ADC sampling rate to a high-speed 250 MHz DSP processing clock via asynchronous CDC FIFO (`adc_fifo`).
* **90% Resource Reduction Target:** Migrates from a 27-DSP parallel baseline down to 5 DSP slices using 5x time-division folding and pre-adder symmetry.
* **Robust CDC & Reset Synchronization:** Incorporates `xpm_cdc_async_rst` for reset deassertion and `xpm_cdc_single` for output level classification flags.
* **Pipelined Control:** Custom DSP macro wrappers configured for optimal pipeline depth (`AREG/ADREG = 1`, `BREG = 2`, `PREG = 1`).

### 2. High-Speed DSP Divider (`02_divider`)
* Hardware division via consecutive shift-subtract operations implemented directly inside cascaded DSP48E1 slices.

### 3. DSP Pattern Detector (`03_pattern_det`)
* Dedicated pattern matching and auto-correlation engine using built-in DSP slice comparator logic.

---

## Design Evolution (Module 1 Roadmap)

The FIR filter implementation progresses through four documented git commit milestones:

1. **Initial Parallel Baseline & Top Integration:** 54-tap symmetric FIR filter with top-level `range_detector` integration, dual-clock domains (250 MHz DSP clock), and async CDC FIFO buffering.
2. **Target Architecture Alignment:** Scaled 50-tap symmetric filter structure.
3. **Time-Division Folding & Timing Closure:** Conversion to a 5x folded 5-DSP array with setup timing closure on Zynq-7000 (-1).
4. **System Integration:** Dual-channel (I/Q) top-level integration feeding downstream processing blocks.

---

## Environment & Toolchain

* **Language:** VHDL-2008
* **Synthesis & Simulation:** AMD Xilinx Vivado / ModelSim / Riviera-PRO
* **Target Device:** Zynq-7000 FPGA Family (`xc7z020clg400-1`)
* **Verification Environment:** GNU Octave / MathWorks MATLAB

---

## License

This project is licensed under the [MIT License](LICENSE).