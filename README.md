# DSP48E1 Mastery: High-Performance FPGA DSP Architectures

A structured repository focused on register-transfer level (RTL) design, pipeline timing closure, and hardware optimization using AMD/Xilinx DSP48E1 primitives in VHDL.

This repository demonstrates how silicon-level hardware design—using pre-adder symmetry, architectural folding, and precise pipeline alignment—can slash DSP slice consumption by up to 90% while closing setup timing on budget silicon.

---

## Repository Structure

```text
dsp48e1-mastery/
├── 01_folded_fir/         # Module 01: Folded Symmetric FIR Filter
│   ├── docs/             # Verification snapshots and documentation assets
│   ├── hdl/              # VHDL RTL sources & DSP wrappers
│   ├── scripts/          # TCL project automation & batch entry points
│   ├── sim/              # Testbenches & waveform configurations (.wcfg)
│   └── README.md         # Detailed module architectural specification
└── README.md             # Top-level repository overview
