# Module 01: Range Detector & Folded Symmetric FIR Filter

Hardware architecture, clock domain management, and pipeline specifications for the DSP48E1-accelerated range detection processing engine.

---

## Architectural Overview

The top-level entity (`range_detector`) processes 16-bit ADC amplitude samples across two distinct clock domains. Input stream data arriving from the system clock domain is buffered into an asynchronous FIFO (`adc_fifo`) and processed inside a high-speed 250 MHz DSP clock domain (`clk_dsp`).

The FIR processing core utilizes a **5x time-division folding architecture**, executing a full **50-tap filter using only 5 DSP48E1 slices** running at 250 MHz (5 cycles per input sample).

```text
                                 +-------------------------------------------------------+
                                 | DSP Clock Domain (250 MHz)                            |
                                 |                                                       |
[Differential Clock] ---> [clk_dsp] ---> dsp_clk_s                                       |
                                 |          |                                            |
[ADC Sample Stream]  ---> [adc_fifo] ------> [fir_impl (5 DSPs, 5x Folded)] ---> [Threshold Det] ---> [xpm_cdc_single] ---> [Level Outputs]
(System Clock)              (CDC)           (DSP48E1 Cascades)                                        (CDC)
```

---

## Hardware Specifications & Resource Utilization

### System Parameters

| Parameter / Module | Setting / Value | Description |
| :--- | :--- | :--- |
| **Top-Level Entity** | `range_detector` | Top integration wrapper with CDC and threshold detection |
| **Testbench Top** | `tb_range_detector` | Differential clocking and noisy stimulus generator |
| **Target Primitive** | `DSP48E1` | AMD/Xilinx 7-Series DSP Slices |
| **Filter Length** | 50 Taps | 25 symmetric pairs processed across 5 folded DSP slices |
| **Clock Frequency** | 250 MHz | DSP domain operational frequency |
| **Timing Closure** | Passed | Clean timing closure (Zero WNS/WHS violations) |
| **Clock IP Core** | `clk_dsp` (`.xci`) | Generates high-speed 250 MHz DSP processing clock |
| **FIFO IP Core** | `adc_fifo` (`.xci`) | Dual-clock asynchronous FIFO for clock domain crossing |
| **Verification Package** | `rtl_golden_ref_vector.vhd` | Simulation vectors for output validation |

### Post-Implementation Resource Utilization (`xc7z020clg400-1`)

| Resource | Utilization | Available | Utilization % |
| :--- | :--- | :--- | :--- |
| **LUT** | 414 | 53,200 | 0.78% |
| **LUTRAM** | 33 | 17,400 | 0.19% |
| **FF** | 924 | 106,400 | 0.87% |
| **BRAM** | 0.50 | 140 | 0.36% |
| **DSP** | **5** | **220** | **2.27%** |
| **IO** | 25 | 125 | 20.00% |
| **BUFG** | 3 | 32 | 9.38% |
| **MMCM** | 1 | 4 | 25.00% |

---

## Directory Structure

```text
01_folded_fir/
├── constraints/
│   └── range_detector.xdc        # Timing constraints (250 MHz clock definition & CDC false paths)
├── hdl/
│   ├── dsp_package.vhd           # Design constants, types, coefficients, and conv_round()
│   ├── dsp_wrapper.vhd           # Parametric DSP48E1 macro wrapper (AREG/BREG/PREG pipeline control)
│   ├── fir_impl.vhd              # 5x time-division folded 5-DSP slice cascade engine
│   └── range_detector.vhd        # Top-level CDC wrapper, IP instances, and thresholding
├── ipcores/
│   ├── clk_dsp/                  # Clocking wizard IP XCI for 250 MHz DSP clock generation
│   └── adc_fifo/                 # Asynchronous CDC FIFO IP XCI
├── sim/
│   ├── rtl_golden_ref_vector.vhd # Golden reference test vector package for simulation
│   └── tb_range_detector.vhd     # Simulation environment with differential clock stimulus
├── scripts/
│   ├── fir_script.tcl            # Project generation TCL script with IP & constraint auto-discovery
│   └── runme.bat                 # One-click Windows batch installer
└── README.md                     # Hardware specification reference
```

---

## Build & Simulation Instructions

1. Run `scripts/runme.bat` to launch project generation.
2. The script automatically imports `.xci` IP cores, VHDL sources, and constraints from `constraints/`.
3. Run simulation on `tb_range_detector` to verify ADC sample processing through `adc_fifo` into the 5x folded FIR core against `rtl_golden_ref_vector`.