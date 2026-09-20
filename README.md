# DSP48E1 Mastery

High-throughput VHDL architectures leveraging AMD/Xilinx DSP48E1 primitives and time-division folding for minimal FPGA logic usage.

This repository demonstrates how silicon-level hardware design—using pre-adder symmetry, architectural folding, and precise pipeline alignment—can slash DSP slice consumption by up to 90% while closing setup timing on budget silicon.

---

## Repository Structure

```text
dsp48e1-mastery/
├── 01_folded_fir/                 # 50-tap folded symmetric FIR filter
│   ├── hdl/                       # VHDL RTL source files & DSP primitive wrappers
│   ├── sim/                       # Testbenches & Octave verification scripts
│   ├── scripts/                   # Automated build & setup scripts
│   │   ├── fir_script.tcl         # Vivado Project Mode generation script
│   │   └── runme.bat              # One-click Windows batch project launcher
│   └── README.md                  # Module architectural reference
├── 02_divider/                    # High-speed shift-subtract division engine (Planned)
└── 03_pattern_det/                # Pattern matching and auto-correlation engine (Planned)