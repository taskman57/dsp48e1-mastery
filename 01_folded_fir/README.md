# Module 01: Range Detector & Folded Symmetric FIR Filter

Hardware architecture, clock domain management, and pipeline specifications for the DSP48E1-accelerated range detection processing engine.

---

## Architectural Overview

The top-level entity (`range_detector`) processes 16-bit ADC amplitude samples across two distinct clock domains. Input stream data arriving from the system clock domain is buffered into an asynchronous FIFO (`adc_fifo`) and processed inside a high-speed 250 MHz DSP clock domain (`clk_dsp`).

The FIR core is scaled to **50 taps**, providing 25 unique symmetric coefficient pairs that directly map onto a 5x time-division folding architecture (5 DSP slices running 5 cycles per sample).

```text
                                 +-------------------------------------------------------+
                                 | DSP Clock Domain (250 MHz)                            |
                                 |                                                       |
[Differential Clock] ---> [clk_dsp] ---> dsp_clk_s                                       |
                                 |          |                                            |
[ADC Sample Stream]  ---> [adc_fifo] ------> [fir_impl (50-Tap)] ---> [Threshold Det] ---> [xpm_cdc_single] ---> [Level Outputs]
(System Clock)              (CDC)           (DSP48E1 Cascades)                                  (CDC)
```

---

## Hardware Specifications & IP Dependencies

| Parameter / Module | Setting / Value | Description |
| :--- | :--- | :--- |
| **Top-Level Entity** | `range_detector` | Top integration wrapper with CDC and threshold detection |
| **Testbench Top** | `tb_range_detector` | Differential clocking and noisy stimulus generator |
| **Target Primitive** | `DSP48E1` | AMD/Xilinx 7-Series DSP Slices |
| **Filter Length** | 50 Taps | 25 symmetric pairs aligned with 5x folding factor |
| **DSP Core Pipeline** | `AREG=1`, `BREG=2`, `PREG=1` | Configured inside direct macro cascades (`fir_impl`) |
| **Clock IP Core** | `clk_dsp` (`.xci`) | Generates high-speed 250 MHz DSP processing clock |
| **FIFO IP Core** | `adc_fifo` (`.xci`) | Dual-clock asynchronous FIFO for clock domain crossing |
| **Verification Package** | `rtl_golden_ref_vector.vhd` | Simulation vectors for output validation |
| **CDC Libraries** | `xpm_cdc_async_rst`, `xpm_cdc_single` | Xilinx Parameterized Macros for safe reset and flag CDC |

---

## Directory Structure

```text
01_folded_fir/
├── hdl/
│   ├── dsp_package.vhd           # Design constants, types, coefficients, and conv_round()
│   ├── fir_impl.vhd              # 50-tap parallel DSP48E1 macro cascade engine
│   └── range_detector.vhd        # Top-level CDC wrapper, IP instances, and thresholding
├── ipcores/
│   ├── clk_dsp/                  # Clocking wizard IP XCI for 250 MHz DSP clock generation
│   └── adc_fifo/                 # Asynchronous CDC FIFO IP XCI
├── sim/
│   ├── rtl_golden_ref_vector.vhd # Golden reference test vector package for simulation
│   └── tb_range_detector.vhd     # Simulation environment with differential clock stimulus
├── scripts/
│   ├── fir_script.tcl            # Project generation TCL script with IP auto-discovery
│   └── runme.bat                 # One-click Windows batch installer
└── README.md                     # Hardware specification reference
```

---

## Build & Simulation Instructions

1. Run `scripts/runme.bat` to launch project generation.
2. The script automatically executes `read_ip` on all `.xci` files inside `ipcores/` and builds the Vivado project.
3. Run simulation on `tb_range_detector` to verify ADC sample processing through `adc_fifo` into the 50-tap FIR core against the `rtl_golden_ref_vector` reference vectors.