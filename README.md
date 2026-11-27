# DSP48E1 Mastery

High-throughput VHDL architectures leveraging AMD/Xilinx DSP48E1 primitives, time-division folding, and internal ALU/comparator logic for minimal FPGA fabric usage.

This repository demonstrates how silicon-level hardware design—using pre-adder symmetry, architectural folding, dynamic ALU control, and built-in pattern detection—can slash LUT and DSP slice consumption while closing setup timing on Zynq-7000 silicon.

---

## Repository Structure

```text
dsp48e1-mastery/
├── 01_folded_fir/                 # 50-tap 5x time-division folded symmetric FIR engine
│   ├── constraints/               # Timing and physical placement constraints (.xdc)
│   ├── docs/                      # Architecture diagrams & timing/simulation snapshots
│   ├── hdl/                       # VHDL RTL sources (dsp_wrapper, fir_impl, range_detector)
│   ├── ipcores/                   # AMD/Xilinx IP core XCI definitions (clk_dsp, adc_fifo)
│   ├── sim/                       # Testbenches, golden ref vectors & verification scripts
│   ├── scripts/                   # Automated build & setup scripts (fir_script.tcl, runme.bat)
│   └── README.md                  # Detailed Module 01 hardware specification
├── 02_divider/                    # Fixed-point dividers, sweep verification & pattern-detect rounding
│   ├── docs/                      # Resource utilization snapshots & design notes
│   ├── m_files/                   # Octave/MATLAB reference models & test scripts
│   ├── rtl_src/                   # Fabric & DSP48E1 sequential divider RTL sources
│   ├── rtl_sim/                   # Full, sweep & DSP step VHDL testbenches
│   └── README.md                  # Detailed Module 02 hardware & verification specification
└── LICENSE
```

---

## Target Modules & Features

### 1. Range Detector & Folded Symmetric FIR Engine (`01_folded_fir`)
* **Dual Clock Domain Processing:** Converts input ADC sampling rates to a high-speed 250 MHz DSP processing clock via an asynchronous CDC FIFO (`adc_fifo`).
* **5x Time-Division Folding:** Executes a 50-tap symmetric FIR filter using 5 DSP48E1 slices running at 250 MHz (5 cycles per input sample).
* **Timing Closure:** Achieves clean setup timing closure with zero timing violations on Zynq-7000 (`xc7z020clg400-1`) silicon.
* **Golden Reference Verification:** Validates RTL simulation outputs against `rtl_golden_ref_vector.vhd`.
* **Robust CDC & Reset Synchronization:** Incorporates `xpm_cdc_async_rst` for reset deassertion and `xpm_cdc_single` for output level classification flags.

### 2. Fixed-Point Divider & Pattern-Detect Rounding (`02_divider`)
* **Fabric & DSP48E1 Sequential Dividers:** Includes parameterized restoring (`div_seq_restoring.vhd`) and non-restoring (`div_seq_nonrestoring.vhd`) dividers alongside DSP48E1-mapped architectures (`DSP_wrapper.vhd`, `dsp_nr_step.vhd`, `div_seq_dsp.vhd`) configured by numerator width (`wn`), divisor width (`wd`), and fractional bits (`frc`).
* **Fabric vs. DSP Resource Comparison:** Captures Vivado resource utilization for both fabric and DSP48E1 non-restoring implementations (`wn=5, wd=3, frc=3`) under `02_divider/docs/`.
* **Integrated Pattern-Detect Rounding:** Designed to fold pattern detection (`PATTERNDETECT` / `PATTERNBDETECT`) into the final rounding stage for fixed-point output handling without extra fabric comparator overhead.
* **Multi-Stage & Parameter-Sweep Verification:** Includes `tb_div_seq_full.vhd` (6 verification stages across `DUT_G` targets), `tb_div_sweep.vhd` across `(wn, wd, frc)` configurations, and `tb_dsp_nr_step.vhd`, paired with reference scripts in `m_files/`.

---

## Design Evolution (Module 01 Roadmap)

The FIR filter implementation progresses through four documented git commit milestones:

1. **Initial Parallel Baseline & Top Integration:** 54-tap symmetric FIR filter with top-level `range_detector` integration, dual-clock domains (250 MHz DSP clock), and async CDC FIFO buffering.
2. **50-Tap Scaling & Golden Reference:** Scaled to 50 taps to align mathematically with 5x time-division folding; integrated golden reference vector package.
3. **Time-Division Folding & Timing Closure (Completed):** Implemented 5x folding engine using DSP slices running at 250 MHz with timing closure and constraint integration.
4. **System Integration:** Dual-channel (I/Q) top-level integration feeding downstream processing blocks.

---

## Environment & Toolchain

* **Language:** VHDL, Octave / MATLAB
* **Synthesis & Simulation:** AMD Xilinx Vivado / GHDL / ModelSim / Riviera-PRO
* **Target Device:** Zynq-7000 FPGA Family (`xc7z020clg400-1`)

---

## License

This project is licensed under the [MIT License](LICENSE).