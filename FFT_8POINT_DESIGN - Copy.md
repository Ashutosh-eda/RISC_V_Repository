# 8-Point FFT Coprocessor Design

## Overview

This document describes the design of an **8-point radix-2 FFT coprocessor** integrated into the RISC-V processor pipeline.

---

## Performance Specifications

- **FFT Size**: 8 points (log₂(8) = 3 stages)
- **Total Cycles**: ~30 cycles (10 cycles per stage × 3 stages)
- **Execution Time**: 120 nanoseconds @ 250 MHz
- **Data Format**: IEEE 754 single-precision floating-point
- **Algorithm**: Decimation-In-Time (DIT) Radix-2

---

## Architecture

### **Block Diagram**

```
┌─────────────────────────────────────────────────────┐
│            8-Point FFT Coprocessor                  │
│                                                     │
│  ┌──────────────┐  ┌────────────────┐              │
│  │ Control Unit │  │ Twiddle ROM    │              │
│  │   (FSM)      │  │  (4 factors)   │              │
│  └──────────────┘  └────────────────┘              │
│                                                     │
│  ┌──────────────────────────────────────┐          │
│  │    Buffer Memory (8 complex samples) │          │
│  │    - 16 × 32-bit (512 bits total)    │          │
│  └──────────────────────────────────────┘          │
│                                                     │
│  ┌──────────────────────────────────────┐          │
│  │  Radix-2 Butterfly (7-cycle pipeline)│          │
│  │    ├─ Complex Multiplier (6 cycles)  │          │
│  │    └─ Complex Adder (1 cycle)        │          │
│  └──────────────────────────────────────┘          │
└─────────────────────────────────────────────────────┘
         ▲                        │
         │                        │
    Commands/Data           Results/Status
         │                        │
         └────────────────────────┘
              CPU Interface
```

---

## FFT Stages

### **3 Stages for 8-Point FFT**

```
Stage 1:                    Stage 2:                    Stage 3:
X[0] ────┬──→ T[0]         T[0] ────┬──→ Y[0]          Y[0] ────┬──→ OUT[0]
X[4] ─W⁰─┘                 T[4] ─W⁰─┘                   Y[4] ─W⁰─┘

X[2] ────┬──→ T[1]         T[2] ────┬──→ Y[1]          Y[2] ────┬──→ OUT[1]
X[6] ─W⁰─┘                 T[6] ─W²─┘                   Y[6] ─W¹─┘

X[1] ────┬──→ T[2]         T[1] ────┬──→ Y[2]          Y[1] ────┬──→ OUT[2]
X[5] ─W⁰─┘                 T[5] ─W⁰─┘                   Y[5] ─W²─┘

X[3] ────┬──→ T[3]         T[3] ────┬──→ Y[3]          Y[3] ────┬──→ OUT[3]
X[7] ─W⁰─┘                 T[7] ─W²─┘                   Y[7] ─W³─┘

        4 butterflies           4 butterflies           4 butterflies
        (W⁰ only)               (W⁰,W²)                 (W⁰,W¹,W²,W³)
```

### **Twiddle Factors for 8-Point**

```
W⁰ = e^(-j·0)    = 1.000 + j·0.000   (0°)
W¹ = e^(-j·π/4)  = 0.707 - j·0.707   (-45°)
W² = e^(-j·π/2)  = 0.000 - j·1.000   (-90°)
W³ = e^(-j·3π/4) = -0.707 - j·0.707  (-135°)
```

---

## Data Storage

### **Buffer Memory Organization**

```
Address  Real Part         Imaginary Part
[0]      X[0]_real         X[0]_imag
[1]      X[1]_real         X[1]_imag
[2]      X[2]_real         X[2]_imag
[3]      X[3]_real         X[3]_imag
[4]      X[4]_real         X[4]_imag
[5]      X[5]_real         X[5]_imag
[6]      X[6]_real         X[6]_imag
[7]      X[7]_real         X[7]_imag

Total: 16 × 32-bit = 512 bits
```

### **Input Order: Bit-Reversed**

For DIT algorithm, input must be in bit-reversed order:

```
Natural Order  →  Bit-Reversed Order
0 (000)        →  0 (000)
1 (001)        →  4 (100)
2 (010)        →  2 (010)
3 (011)        →  6 (110)
4 (100)        →  1 (001)
5 (101)        →  5 (101)
6 (110)        →  3 (011)
7 (111)        →  7 (111)
```

---

## Custom Instructions

### **11 Custom Instructions (Same as Paper)**

**Opcode**: `7'b0001011` (custom-0)

| Instruction | funct7 | funct3 | rd | rs1 | Description |
|-------------|--------|--------|----|----|-------------|
| `fftloadRe.f` | 0x00 | 0x2 | - | fs1 | Load real part from FP reg |
| `fftloadIm.f` | 0x01 | 0x2 | - | fs1 | Load imag part from FP reg |
| `fftstoreRe.f` | 0x00 | 0x3 | fd | - | Store real part to FP reg |
| `fftstoreIm.f` | 0x01 | 0x3 | fd | - | Store imag part to FP reg |
| `fftstart` | 0x00 | 0x1 | - | - | Start FFT execution |
| `fftstatus` | 0x00 | 0x4 | rd | - | Read status (busy/ready) |

**Note**: Integer register variants omitted for simplicity (we only use FP registers).

---

## Usage Example

### **Assembly Code to Execute 8-Point FFT**

```assembly
# Load 8 complex samples into FFT buffer (bit-reversed order)
fftloadRe.f f0, 0    # X[0] real
fftloadIm.f f1, 0    # X[0] imag
fftloadRe.f f2, 4    # X[4] real  (bit-reversed)
fftloadIm.f f3, 4    # X[4] imag
fftloadRe.f f4, 2    # X[2] real
fftloadIm.f f5, 2    # X[2] imag
fftloadRe.f f6, 6    # X[6] real
fftloadIm.f f7, 6    # X[6] imag
fftloadRe.f f8, 1    # X[1] real
fftloadIm.f f9, 1    # X[1] imag
fftloadRe.f f10, 5   # X[5] real
fftloadIm.f f11, 5   # X[5] imag
fftloadRe.f f12, 3   # X[3] real
fftloadIm.f f13, 3   # X[3] imag
fftloadRe.f f14, 7   # X[7] real
fftloadIm.f f15, 7   # X[7] imag

# Start FFT computation
fftstart

# Poll until complete (busy-wait loop)
wait_loop:
    fftstatus x1
    andi x1, x1, 1       # Check ready bit
    beqz x1, wait_loop

# Read results (in natural order)
fftstoreRe.f f16, 0   # Y[0] real
fftstoreIm.f f17, 0   # Y[0] imag
fftstoreRe.f f18, 1   # Y[1] real
fftstoreIm.f f19, 1   # Y[1] imag
# ... etc for Y[2] through Y[7]
```

---

## Performance Comparison

| Implementation | Cycles | Time @ 250MHz | Speedup |
|----------------|--------|---------------|---------|
| **Software FFT** | ~800 | 3.2 μs | 1× |
| **This Coprocessor** | 30 | 0.12 μs | **27×** |

---

## Module Files

1. **[twiddle_rom_8pt.v](twiddle_rom_8pt.v)** - Pre-computed W factors
2. **[complex_multiplier.v](complex_multiplier.v)** - (a+jb)×(c+jd)
3. **[fft_butterfly_radix2.v](fft_butterfly_radix2.v)** - Butterfly computation
4. **fft_buffer_8pt.v** - 8-sample buffer memory (to be created)
5. **fft_control_8pt.v** - FSM controller (to be created)
6. **fft_coprocessor_8pt.v** - Top-level integration (to be created)

---

## Next Steps

1. Create buffer memory module
2. Create control FSM
3. Create top-level coprocessor
4. Integrate into execute stage
5. Add FFT instructions to decode stage
6. Test with sample data

---

## Design Notes

- **No bit-reversal hardware**: CPU performs bit-reversal during load
- **Sequential butterfly**: Only 1 butterfly unit (simpler than parallel)
- **Fixed-size**: 8 points only (not scalable, but very efficient)
- **No normalization**: Output scaled by factor of 8 (user handles)

