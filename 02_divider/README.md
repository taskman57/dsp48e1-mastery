# Module 02: Fixed-Point Divider & Pattern-Detect Rounding

Algorithm reference models, fabric and DSP48E1 sequential fixed-point divider RTL, multi-configuration and step-level testbenches, GHDL simulation flow, and final-stage pattern-detection rounding integration.

---

## Architectural Overview

This module implements fixed-point sequential division across configurable bit widths:
* **Numerator Width (`wn`):** Bit width of the input dividend (`num_i`).
* **Divisor Width (`wd`):** Bit width of the input divisor (`den_i`), which also defines the remainder output width (`rem_o`).
* **Fractional Bits (`frc`):** Number of fractional bits scaled into the quotient output (`quot_o` has width `wn + frc`).

Key RTL components in `rtl_src/`:
* **Restoring Divider (`div_seq_restoring.vhd`):** Shifts `rem_v` with the next numerator bit (or `'0'` for fractional steps), subtracts `den_s` when `rem_v >= den_s` (shifting `'1'` into `quot_s`), or shifts `'0'` into `quot_s` otherwise.
* **Non-Restoring Divider (`div_seq_nonrestoring.vhd`):** Uses signed `rem_v` and `den_s` (`wd+1 downto 0`), dynamically subtracting `den_s` when `rem_v >= 0` or adding `den_s` when `rem_v < 0`, shifting `'0'` or `'1'` into `quot_s` based on the resulting sign, and performing a final remainder sign adjustment (`rem_v + den_s` when `rem_v < 0`) upon completion.
* **DSP48E1 Non-Restoring Step & Wrapper (`DSP_wrapper.vhd`, `dsp_nr_step.vhd`, `divider_pkg.vhd`, `div_seq_dsp.vhd`):** Maps non-restoring shift/add/subtract operations onto a `DSP48E1` primitive (`PREG = 1`, 48-bit `P`/`C` datapath supporting `wd <= 46`) with final-stage sign correction when the final remainder is negative.

In the broader module roadmap, **pattern detection** (`PATTERNDETECT` / `PATTERNBDETECT`) is being integrated into the final rounding stage for fixed-point division outputs.

```text
[num_i (wn)] ──┐
               ├──▶ [Divider Core: Restoring / Non-Restoring / DSP48E1] ──▶ [Final Rounding / Pattern Detect] ──▶ [quot_o (wn+frc), rem_o (wd), rdy_o, err_o]
[den_i (wd)] ──┘                                                                  (Fixed-Point Rounding)
```

---

## Resource Utilization (`wn = 5, wd = 3, frc = 3`)

### Fabric Non-Restoring Implementation
![Fabric Non-Restoring Resource Usage (`wn=5, wd=3, frc=3`)](docs/resource_fab_seq_nr_wn5_wd3_frc3.png)

### DSP48E1 Non-Restoring Implementation
![DSP48E1 Non-Restoring Resource Usage (`wn=5, wd=3, frc=3`)](docs/resource_dsp__nr_wn5_wd3_frc3.png)

---

## Directory Structure

```text
02_divider/
├── docs/
│   ├── resource_dsp__nr_wn5_wd3_frc3.png     # DSP48E1 non-restoring resource utilization snapshot
│   └── resource_fab_seq_nr_wn5_wd3_frc3.png # Fabric non-restoring resource utilization snapshot
├── m_files/
│   ├── div_restoring.m                      # Restoring division reference script
│   ├── div_nonrestoring.m                   # Non-restoring division reference script
│   └── div_tester.m                         # Algorithm testing and verification script
├── rtl_src/
│   ├── div_seq_dsp.vhd                      # DSP-based sequential divider RTL
│   ├── div_seq_nonrestoring.vhd             # Parameterized sequential non-restoring divider
│   ├── div_seq_restoring.vhd                # Parameterized sequential restoring divider
│   ├── divider_pkg.vhd                      # DSP48E1 control constants, rounding & helper functions
│   ├── dsp_nr_step.vhd                      # DSP48E1-based sequential non-restoring divider
│   └── DSP_wrapper.vhd                      # Xilinx DSP48E1 primitive wrapper
├── rtl_sim/
│   ├── tb_div_seq_full.vhd                  # 6-stage monolithic testbench (configurable DUT_G)
│   ├── tb_div_sweep.vhd                     # Multi-configuration (wn, wd, frc) sweep testbench
│   └── tb_dsp_nr_step.vhd                   # Directed testbench for dsp_nr_step
└── README.md                                # Module 02 hardware, GHDL simulation, and verification specification
```

---

## Verification & Testbenches

### 1. Six-Stage Verification (`rtl_sim/tb_div_seq_full.vhd`)
Selects the DUT via `DUT_G` (`0` for `div_seq_restoring`, `1` for `div_seq_nonrestoring`, and `2` for `dsp_nr_step` when wired in) and evaluates six stages for a given `(wn, wd, frc)` configuration:
1. **Reference-Model Verification:** Checks quotient and remainder against $\lfloor n \cdot 2^{\text{frc}} / d \rfloor$ and $(n \cdot 2^{\text{frc}}) \bmod d$.
2. **Mini Scoreboard:** Verifies fractional, repeating-binary, power-of-two, and near-unity ratios.
3. **Corner Cases:** Covers zero dividend, unit divisor, equal operands, dividend smaller than divisor, and wide (>32-bit) hex vectors via `num_u` and `den_u`.
4. **Robustness:** Tests boundary operands (`MAX_NUM_C`, `MAX_DEN_C`) and mid-transaction synchronous reset (`rst_i`).
5. **Divide-by-Zero:** Confirms `err_o` assertion on zero divisor and recovery on subsequent valid divisions.
6. **Randomized Reference Model:** Runs `NUM_TESTS_G` pseudo-random operand pairs per configuration.

### 2. Multi-Configuration Sweep (`rtl_sim/tb_div_sweep.vhd`)
Runs `tb_div_seq_full` across `(wn, wd, frc)` configurations in `CFGS_C` with configurable `NUM_TESTS_G` and `VERBOSE_G`, printing a consolidated pass/fail table at completion (keeping `wd <= 46` for single-slice 48-bit `DSP48E1` datapaths).

### 3. DSP Non-Restoring Step Testbench (`rtl_sim/tb_dsp_nr_step.vhd`)
Exercises `dsp_nr_step` across directed `(dividend, divisor)` stimulus vectors and monitors `quot_o`, `rem_o`, `busy_o`, `rdy_o`, and `err_o`.

---

## Compilation & Simulation (GHDL)

To compile the RTL sources and run the multi-configuration sweep testbench in GHDL using VHDL-2008 (`--std=08`):

### 1. Analyze Design and Testbench Files
```sh
ghdl -a --std=08 div_seq_restoring.vhd div_seq_nonrestoring.vhd tb_div_seq_full.vhd tb_div_sweep.vhd
```
*(Note: If running from the `02_divider/` root directory, prefix the file paths with `rtl_src/` and `rtl_sim/` respectively; for `DSP_wrapper.vhd` and `dsp_nr_step.vhd`, also analyze `divider_pkg.vhd` and pass `-P<ghdl_unisim_dir>` pointing to your compiled `unisim` `DSP48E1` units.)*

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
* **DSP48E1 Primitive Mapping & Refinement:** Complete verification and timing/resource documentation across `DSP_wrapper.vhd`, `dsp_nr_step.vhd`, and `div_seq_dsp.vhd`.