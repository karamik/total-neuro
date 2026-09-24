# Verification Report — consent_gate

**Status:** Formally verified (k-induction, unbounded depth).
**Date:** 2026-09-24
**Toolchain:** Icarus Verilog 12.0, Yosys 0.66, yosys-smtbmc + z3.

---

## What was verified

`rtl/consent_gate.sv` — critical command gate. The module only
passes a command to the actuator when:

1. A valid cryptographic signature is presented
   (`sig_ecdsa_valid_i & sig_dilithium_valid_i`, or `both_valid_i`
   from an isolated verifier), **and**
2. A physical human consent signal is asserted
   (`external_consent_i`), **and**
3. No tamper has been detected (`tamper_detect_i`).

Once tamper is detected, the kill switch latches permanently.
Reset does not revive the FSM.

---

## Methods

### 1. Simulation (Icarus Verilog)

Testbenches:
- `tb/consent_gate_tb.sv` — 9 scenarios on the bare gate.
- `tb/top_arty_a7_tb.sv` — 6 scenarios on the FPGA wrapper.
- `tb/pq_integration_tb.sv` — 6 scenarios with the MCU interface.

All pass. No phantom events, no lost CDC pulses, no reset-revival.

### 2. Synthesis (Yosys)

Read, hierarchy, proc, opt, check -assert, synth -top consent_gate, stat.

Result: 336 cells, 0 problems. No latches, no memories, no
multi-driver nets.

### 3. Bounded Model Checking (BMC)

Command: yosys-smtbmc -s z3 -t 100 formal/consent_gate.smt2

Result: PASSED at depth 100. 23 seconds on Termux / aarch64.

### 4. Temporal Induction (k-induction)

Command: yosys-smtbmc -i -s z3 -t 30 formal/consent_gate.smt2

Result: PASSED. Temporal induction successful.

This is not bounded verification. It is a mathematical proof that
the assertions below hold for all reachable states, regardless
of input sequence depth.

---

## Assertions proved

Let state_r be the FSM state register, state be the effective
state (kill_switch ? ZEROIZE : state_r), and gated_cmd_valid
be the output that opens the critical bus.

| # | Invariant | Meaning |
|---|-----------|---------|
| 1 | kill_switch is sticky | Once latched, it stays high forever. Reset does not clear it. |
| 2a | Entering WAIT_CONSENT requires past valid crypto | FSM cannot reach consent stage without a valid signature path. |
| 2b | Entering PASS requires past consent | FSM cannot enter pass state without human consent in the transition cycle. |
| 2c | gated_cmd_valid implies state == S_PASS | Critical bus only opens from the pass state. |
| 3 | NOT(kill_switch AND gated_cmd_valid) | After tamper, no command can pass. Ever. |

These five properties define the safety envelope of the gate.
They were proved, not tested.

---

## What is NOT verified

1. Cryptography is not in RTL. The signals
   sig_ecdsa_valid_i, sig_dilithium_valid_i, and both_valid_i
   are assumed to be correct outputs of an external verifier. The
   formal proof shows that IF they are asserted, the gate behaves
   correctly. It does NOT prove that the verifier itself is
   sound. That lives on a physically isolated MCU.

2. pq_verifier_mcu.v is not formally verified. Its logic is
   simpler (heartbeat watchdog + edge detect), but it is only
   covered by simulation. Extending the formal proof to this module
   is a natural next step.

3. No physical hardware run. The FPGA wrapper
   (rtl/top_arty_a7.sv) and XDC constraints are provided, but
   have not been tested on a physical Arty A7 board.

4. Liveness not proved. The invariants are safety properties
   ("nothing bad happens"). They do not prove that a valid command
   eventually passes, or that a stuck FSM eventually refuses.
   Adding cover() properties and liveness checks is possible but
   not done here.

5. Timing not verified. CDC correctness is structural (toggle
   synchronizer, 3-FF chains). Propagation delay, metastability
   MTBF, and skew are outside the scope of this proof.

---

## Reproducing

Step 1 — generate the SMT2 model:

    yosys -p "read_verilog -sv rtl/consent_gate.sv; read_verilog -sv formal/consent_gate_formal.sv; prep -top consent_gate_formal; async2sync; dffunmap; write_smt2 -wires formal/consent_gate.smt2"

Step 2 — BMC to depth 100:

    yosys-smtbmc -s z3 -t 100 formal/consent_gate.smt2

Step 3 — k-induction:

    yosys-smtbmc -i -s z3 -t 30 formal/consent_gate.smt2

Both must print Status: PASSED.

---

## Interpretation

This is not "we ran some tests and nothing broke." It is a proof
that the design satisfies its safety invariants for all reachable
states. The toolchain is the same class of tool used in ARM, Intel,
NASA JPL, and Airbus verification flows.

The limitations above are real. They mark the boundary between
"what was proved" and "what is assumed." For a hardware root of
trust in an AI system, these boundaries should be documented as
clearly as the guarantees.

Artifacts: formal/yosys.log, formal/bmc.log, formal/bmc_100.log,
formal/bmc_induction.log.
