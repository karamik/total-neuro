# FPGA Demo - TOTAL-Neuro

**Run the TOTAL-Neuro Loader FSM + security modules on real FPGA hardware.**

This guide walks you through synthesizing and programming the design on a **Digilent Arty A7-35T** board. No prior FPGA experience required.

---

## What You Will See

After programming the board:

| LED | Meaning |
|-----|---------|
| led[0] | Loader FSM finished successfully (load_done) |
| led[1] | Load error (load_error) - signature mismatch or malformed firmware |
| led[2] | Active Shield is intact (shield_ok) |
| led[3] | Apollo-2 kill switch triggered (kill_triggered) |
| led[4] | Heartbeat (blinks ~1.5 Hz) - proof the clock is alive |
| led[15:8] | Fast-changing counter - visual activity |

**Controls:**

| Input | Action |
|-------|--------|
| btn[0] | Reset (active high) |
| btn[1] | Start firmware load |
| btn[2] | Arm Apollo-2 kill switch |
| sw[0] | Firmware select: 0 = valid signature, 1 = corrupted signature |

---

## Prerequisites

| Item | Notes |
|------|-------|
| **Arty A7-35T** | Digilent board (~$200) |
| **USB cable** | Micro-USB |
| **Vivado** | 2022.2 or later, WebPACK edition (free) |
| **Xilinx cable drivers** | Installed with Vivado |
| **Disk space** | ~15 GB for Vivado install |

---

## Step 1 - Clone the Repository

Open a terminal and run:

    git clone https://github.com/karamik/total-neuro.git
    cd total-neuro

---

## Step 2 - Run Vivado Synthesis

Install Vivado (WebPACK is free), then launch it in batch mode from the project root:

    vivado -mode batch -source fpga/scripts/create_project.tcl

This single command will:

1. Create a Vivado project in build/total_neuro_demo/
2. Add all RTL sources and constraints
3. Run synthesis
4. Run implementation and generate a bitstream
5. Save timing and utilization reports

**Expected time:** 5-10 minutes on a modern laptop.

**Expected result:**

    === Synthesis complete ===
    === Implementation complete ===
    === Bitstream generated: ./build/total_neuro_demo/.../top_fpga.bit ===

If you see these lines - the design is ready.

---

## Step 3 - Program the Board

### Option A: Using Vivado GUI

1. Open Vivado -> Open Hardware Manager
2. Click Open Target -> Auto Connect
3. Click Program Device -> select top_fpga.bit

### Option B: Using Tcl (batch mode)

    vivado -mode batch -source fpga/scripts/program.tcl

---

## Step 4 - Run the Demo

1. Connect the Arty A7 board to your computer via micro-USB.
2. Power on the board.
3. Program the bitstream (Step 3).
4. Watch the LEDs:

### Test 1: Successful Load

- Set sw[0] = 0 (valid firmware).
- Press btn[0] to reset.
- Press btn[1] to start loading.
- Expected result:
  - led[0] turns ON (load_done)
  - led[2] stays ON (shield_ok)
  - led[1] stays OFF (no error)
  - led[4] blinks (heartbeat)
  - led[15:8] shows activity

### Test 2: Corrupted Firmware

- Set sw[0] = 1 (corrupted signature).
- Press btn[0] to reset.
- Press btn[1] to start loading.
- Expected result:
  - led[1] turns ON (load_error)
  - led[0] stays OFF (load failed)

### Test 3: Apollo-2 Kill Switch

- Press btn[2] to arm the kill switch.
- Trigger a fault (set sw[0] = 1 and load).
- Expected result:
  - led[3] turns ON (kill_triggered)
  - All other activity stops

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Vivado not found | Add Vivado bin/ to PATH, or launch from Vivado GUI |
| Board not detected | Install Xilinx cable drivers, check USB cable |
| Synthesis fails | Check that all .sv files are present in rtl/ and fpga/ |
| Bitstream not generated | Check build/total_neuro_demo/*.rpt for errors |
| LEDs do not change | Press btn[0] to reset, then btn[1] to start |

---

## Board Alternatives

This demo targets **Arty A7-35T**. Other Xilinx 7-series boards can be used with modified constraints:

| Board | FPGA | Constraint file |
|-------|------|-----------------|
| Arty A7-35T | XC7A35T | fpga/constraints/arty_a7.xdc (default) |
| Arty A7-100T | XC7A100T | Same XDC, different part number |
| Basys 3 | XC7A35T | Requires new XDC |
| Nexys A7 | XC7A100T | Requires new XDC |

To adapt, edit fpga/constraints/arty_a7.xdc with the correct pin mappings for your board.

---

## What This Demo Proves

By running this on real hardware, you verify:

- **Loader FSM works in silicon** - not just in simulation
- **Active Shield + Health Monitor** correctly detect intrusion vs aging
- **Apollo-2 Kill Switch** physically responds to faults
- **Cycle Monitor** detects clock glitches in real time
- **No CPU is needed** - the entire boot sequence runs on bare-metal FSM

This is the same architecture that will be taped out on TSMC 28 nm in 2027.

---

## Contact

- Repository: github.com/karamik/total-neuro
- Telegram: @tec_support_bot
- Issues: github.com/karamik/total-neuro/issues

---

**License:** MIT (open part) / Commercial (full stack)
**Copyright 2026 TOTAL Protocol Foundation**
