# Module 02: Fixed-Point Divider & Pattern-Detect Rounding

Algorithm reference models, sequential fixed-point divider RTL (`div_seq_restoring` and `div_seq_nonrestoring`), multi-configuration testbenches, GHDL simulation flow, and final-stage pattern-detection rounding integration.

---

## Architectural Overview

This module implements fixed-point sequential division across configurable bit widths:
* **Numerator Width (`wn`):** Bit width of the input dividend (`num_i`).
* **Divisor Width (`wd`):** Bit width of the input divisor (`den_i`), which also defines the remainder output width (`rem_o`).
* **Fractional Bits (`frc`):** Number of fractional bits scaled into the quotient output (`quot_o` has width `wn + frc`).

Both `rtl_src/div_seq_restoring.vhd` and `rtl_src/div_seq_nonrestoring.vhd` use a compact three-state (`0`, `1`, `2`) synchronous control path with rising-edge enable (`ena_i`), `busy_o` and `rdy_o` handshake signals, quotient/remainder outputs, and divide-by-zero error reporting (`err_o`):
* **Restoring Divider (`div_seq_restoring.vhd`):** Shifts `rem_v` with the next numerator bit (or `'0'` for fractional steps), subtracts `den_s` when `rem_v >= den_s` (shifting `'1'` into `quot_s`), or restores/shifts `'0'` into `quot_s` otherwise.
* **Non-Restoring Divider (`div_seq_nonrestoring.vhd`):** Uses signed `rem_v` and `den_s` (`wd+1 downto 0`), dynamically subtracting `den_s` when `rem_v >= 0` or adding `den_s` when `rem_v < 0`, shifting `'0'` or `'1'` into `quot_s` based on the resulting sign, and performing a final remainder sign adjustment (`rem_v + den_s` when `rem_v < 0`) upon completion.

In the broader module roadmap, **pattern detection** (`PATTERNDETECT` / `PATTERNBDETECT`) is being integrated into the final rounding stage for fixed-point division outputs.

```text
[num_i (wn)] ──┐
               ├──▶ [Divider Core: div_seq_restoring (DUT_G=0) / div_seq_nonrestoring (DUT_G=1)] ──▶ [Final Rounding / Pattern Detect] ──▶ [quot_o (wn+frc), rem_o (wd), rdy_o, err_o]
[den_i (wd)] ──┘                                                                                           (Fixed-Point Rounding)
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
│   ├── div_seq_restoring.vhd     # Parameterized sequential restoring divider (generics: wn, wd, frc)
│   └── div_seq_nonrestoring.vhd  # Parameterized sequential non-restoring divider (generics: wn, wd, frc)
├── rtl_sim/
│   ├── tb_div_seq_full.vhd       # 6-stage monolithic testbench (DUT_G: 0=restoring, 1=non-restoring)
│   └── tb_div_sweep.vhd          # Multi-configuration (18 sets in CFGS_C) sweep testbench
└── README.md                     # Module 02 hardware, GHDL simulation, and verification specification
```

---

## Verification & Testbenches

### 1. Six-Stage Verification (`rtl_sim/tb_div_seq_full.vhd`)
Selects the DUT via `DUT_G` (`0` for `div_seq_restoring`, `1` for `div_seq_nonrestoring`) and evaluates six stages for a given `(wn, wd, frc)` configuration:
1. **Reference-Model Verification:** Checks quotient and remainder against $\lfloor n \cdot 2^{\text{frc}} / d \rfloor$ and $(n \cdot 2^{\text{frc}}) \bmod d$.
2. **Mini Scoreboard:** Verifies fractional, repeating-binary, power-of-two, and near-unity ratios.
3. **Corner Cases:** Covers zero dividend, unit divisor, equal operands, dividend smaller than divisor, and wide (>32-bit) hex vectors via `num_u` and `den_u`.
4. **Robustness:** Tests boundary operands (`MAX_NUM_C`, `MAX_DEN_C`) and mid-transaction synchronous reset (`rst_i`).
5. **Divide-by-Zero:** Confirms `err_o` assertion on zero divisor and recovery on subsequent valid divisions.
6. **Randomized Reference Model:** Runs `NUM_TESTS_G` pseudo-random operand pairs per configuration.

### 2. Multi-Configuration Sweep (`rtl_sim/tb_div_sweep.vhd`)
Runs `tb_div_seq_full` across all 18 `(wn, wd, frc)` configurations in `CFGS_C` (including `(34, 10, 4)`, `(57, 51, 4)`, `(34, 10, 0)`, `(5, 3, 3)`, wide divisors such as `(60, 62, 0)`, fractional-heavy sets such as `(40, 12, 20)`, `(1, 1, 0)`, and `(8, 8, 8)`) with configurable `NUM_TESTS_G` (default `1000`) and `VERBOSE_G`, printing a summary table at the end.

---

## Compilation & Simulation (GHDL)

To compile the RTL sources and run the multi-configuration sweep testbench in GHDL using VHDL-2008 (`--std=08`):

### 1. Analyze Design and Testbench Files
```sh
ghdl -a --std=08 div_seq_restoring.vhd div_seq_nonrestoring.vhd tb_div_seq_full.vhd tb_div_sweep.vhd
```
*(Note: If running from the `02_divider/` root directory, prefix the file paths with `rtl_src/` and `rtl_sim/` respectively.)*

### 2. Elaborate the Sweep Testbench
```sh
ghdl -e --std=08 tb_div_sweep
```

### 3. Run Simulation and Dump Waveforms
```sh
ghdl -r --std=08 tb_div_sweep --wave=nonrestoring.ghw --stop-time=25000us
```
*(You can inspect the generated `nonrestoring.ghw` waveform file in GTKWave.)*

---

## Roadmap & Active Development

* **Final-Stage Pattern Detection & Rounding:** Integrate `PATTERNDETECT` / `PATTERNBDETECT` into the final rounding stage of the fixed-point divider pipeline.
* **DSP48E1 Primitive Mapping:** Transition sequential arithmetic stages toward hardened DSP48E1 datapath/ALU structures and document resource/timing results under `docs/`.