# Module 02: Fixed-Point Divider & Pattern-Detect Rounding

Algorithm reference models, sequential fixed-point divider RTL, multi-configuration testbenches, and final-stage pattern-detection rounding integration.

---

## Architectural Overview

This module focuses on fixed-point division and rounding precision across configurable bit widths:
* **Numerator Width (`wn`):** Bit width of the input dividend (`num_i`).
* **Divisor Width (`wd`):** Bit width of the input divisor (`den_i`), which also sets the remainder output width (`rem_o`).
* **Fractional Bits (`frc`):** Number of fractional bits scaled into the quotient output (`quot_o` has width `wn + frc`).

Currently, `rtl_src/div_seq_restoring.vhd` implements a sequential restoring division state machine with rising-edge enable (`ena_i`), `busy_o` and `rdy_o` handshake signals, quotient/remainder outputs, and divide-by-zero error reporting (`err_o`).

In the broader module roadmap, non-restoring division (`div_seq_nonrestoring`) and **pattern detection** (`PATTERNDETECT` / `PATTERNBDETECT`) are being integrated directly into the final rounding stage for fixed-point division results.

```text
[num_i (wn)] ──┐
               ├──▶ [Divider Core (div_seq_restoring / planned non-restoring)] ──▶ [Final Rounding / Pattern Detect] ──▶ [quot_o (wn+frc), rem_o (wd), rdy_o, err_o]
[den_i (wd)] ──┘                                                                         (Fixed-Point Rounding)
```

---

## Directory Structure

```text
02_divider/
├── docs/
│   └── .gitkeep                  # Diagrams, timing captures, and design notes
├── m_files/
│   ├── div_restoring.m           # Restoring division reference script
│   ├── div_nonrestoring.m        # Non-restoring division reference script
│   └── div_tester.m              # Algorithm testing and verification script
├── rtl_src/
│   └── div_seq_restoring.vhd     # Parameterized sequential restoring divider (generics: wn, wd, frc)
├── rtl_sim/
│   ├── tb_div_seq_restoring_full.vhd # 6-stage verification testbench (configurable DUT_G, VERBOSE_G, NUM_TESTS_G)
│   └── tb_div_sweep.vhd          # Multi-configuration (wn, wd, frc) sweep testbench
└── README.md                     # Module 02 hardware and verification specification
```

---

## Verification & Testbenches

### 1. Six-Stage Verification (`rtl_sim/tb_div_seq_restoring_full.vhd`)
Evaluates the divider across six sequential stages for a given `(wn, wd, frc)` configuration:
1. **Reference-Model Verification:** Compares quotient and remainder against `floor(n * 2^frc / d)` and `n * 2^frc - q * d`.
2. **Mini Scoreboard:** Checks fractional, repeating-binary, power-of-two, and near-unity ratios.
3. **Corner Cases:** Tests zero dividend, unit divisor, equal operands, and dividend-smaller-than-divisor cases.
4. **Robustness:** Exercises boundary operands (`MAX_NUM_C`, `MAX_DEN_C`) and mid-transaction synchronous reset assertion (`rst_i`).
5. **Divide-by-Zero:** Verifies `err_o` assertion on zero divisor and clean recovery on subsequent valid divisions.
6. **Randomized Reference Model:** Runs `NUM_TESTS_G` pseudo-random operand pairs per configuration.

### 2. Multi-Configuration Sweep (`rtl_sim/tb_div_sweep.vhd`)
Instantiates `tb_div_seq_restoring_full` across multiple `(wn, wd, frc)` rows defined in `CFGS_C` (including `(34, 10, 4)`, `(60, 53, 4)`, `(34, 10, 0)`, `(5, 3, 3)`, `(4, 6, 0)`, `(1, 1, 0)`, and `(8, 8, 8)`) and reports a consolidated pass/fail table at completion.

---

## Roadmap & Active Development

* **Non-Restoring Divider (`DUT_G = 1`):** Add `div_seq_nonrestoring.vhd` in `rtl_src/` and enable the `dut_1` generate hook in `tb_div_seq_restoring_full.vhd`.
* **Final-Stage Pattern Detection & Rounding:** Combine pattern detection into the final stage of the fixed-point divider pipeline to handle rounding cleanly alongside quotient/remainder output generation.
* **Documentation & Waveforms:** Add architectural diagrams and simulation/timing captures under `docs/`.