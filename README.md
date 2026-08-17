# PipeAES-128

**An 11-stage pipelined AES-128 encryption core in Verilog, targeting the PYNQ-Z2.**

After an 11-cycle fill, the core produces **one 128-bit ciphertext block per clock cycle**. The
key schedule was moved out of combinational logic into a sequential 11-cycle expander to keep it
off the critical path.

This repository holds two designs: the iterative baseline it started from, and the pipelined
rewrite that replaces it.

---

## Contents

| Path | What it is |
|---|---|
| [AES Pipelined/](AES%20Pipelined/) | The pipelined core — the actual deliverable |
| [original/](original/) | The HelloIITK iterative baseline, kept for comparison |
| [Assignment 1 - Pipelined AES Encryption.png](Assignment%201%20-%20Pipelined%20AES%20Encryption.png) | Assignment brief |
| `IOTians.pptx` | Team presentation |

---

## Architecture

### Baseline ([original/](original/))

One AES round per clock, folded onto a single round of hardware. `roundCount` walks 1 → 11,
selecting the round key each cycle, and the whole 11-round key schedule is generated
**combinationally** by [KeyExpansion.v](original/KeyExpansion.v) — ten `KeyExpansionRound`
instances chained back to back, so the key path is one enormous ripple of S-boxes and XORs.

- ~11 cycles per block
- Only one block in flight; a new block needs a reset
- Long combinational key path caps the achievable clock

### Pipelined ([AES Pipelined/](AES%20Pipelined/))

Two independent changes, matching points 2 and 3 of the brief:

**1. Sequential key expansion** — [aes128_key_expand_seq.v](AES%20Pipelined/aes128_key_expand_seq.v)
computes one round key per cycle from a 4-word register (`w0..w3`), applying
`RotWord → SubWord → Rcon`. Round keys land in a `11×128` register file over 11 cycles, then
`done` pulses. The critical path shrinks to a single `SubWord` plus a few XORs instead of ten
chained expansions.

**2. Fully unrolled datapath** — [aes128_pipeline_seqkeys.v](AES%20Pipelined/aes128_pipeline_seqkeys.v#L63)
instantiates all 11 rounds as separate hardware with a pipeline register between each:

```
in_block ─►[ARK rk0]─►[R1]─►[R2]─► … ─►[R9]─►[R10 final]─► out_block
             stage0    s1     s2          s9      s10
```

- Stage 0: `AddRoundKey(rk0)`
- Stages 1–9: `SubBytes → ShiftRows → MixColumns → AddRoundKey` ([GEN_ROUNDS](AES%20Pipelined/aes128_pipeline_seqkeys.v#L123))
- Stage 10: `SubBytes → ShiftRows → AddRoundKey` — no `MixColumns`, per FIPS-197

A `stage_valid` bit shifts alongside the data, so `out_valid` marks exactly which cycles carry
real ciphertext.

### Round primitives

| Module | Note |
|---|---|
| [aes_subbytes.v](AES%20Pipelined/aes_subbytes.v) | 16 parallel S-box lookups |
| [aes_shiftrows.v](AES%20Pipelined/aes_shiftrows.v) | Pure rewiring — zero logic |
| [aes_mixcolumns.v](AES%20Pipelined/aes_mixcolumns.v) | GF(2⁸) `xtime`-based ×2 / ×3 |
| [aes_sbox.v](AES%20Pipelined/aes_sbox.v) | 256-byte table as a `localparam`, read via a function |

---

## Interface

```verilog
aes128_pipeline_seqkeys dut (
    .clk(clk), .rst_n(rst_n),        // active-low reset
    .key_valid(key_valid),           // pulse 1 cycle to (re)load the key
    .key(key),                       // [127:0]
    .keys_ready(keys_ready),         // high once rk0..rk10 are available
    .in_valid(in_valid), .in_block(in_block), .in_ready(in_ready),
    .out_valid(out_valid), .out_block(out_block)
);
```

**Usage:** pulse `key_valid` for one cycle → wait for `keys_ready` → drive `in_valid` with a new
`in_block` every cycle. Ciphertext appears on `out_block` whenever `out_valid` is high, in the
same order it went in.

`in_ready` is simply `keys_ready`: once the keys are loaded the pipeline accepts a block every
cycle and never stalls. The consumer must therefore be able to accept a block every cycle too —
there is no output backpressure.

---

## Results

Measured with Icarus Verilog 12.0 on the FIPS-197 Appendix C.1 vector
(`key = 000102030405060708090a0b0c0d0e0f`, `pt = 00112233445566778899aabbccddeeff`):

```
Ciphertext = 69c4e0d86a7b0430d8cdb78070b4c55a   ✓ matches FIPS-197
```

| | Baseline | Pipelined |
|---|---|---|
| Key expansion | Combinational | Sequential, 11 cycles |
| Initial latency | ~11 cycles | 11 cycles (after `keys_ready`) |
| Steady-state throughput | 1 block / ~11 cycles | **1 block / cycle** |
| Blocks in flight | 1 | 11 |
| Relative throughput | 1× | **≈11×** |

Streaming four back-to-back blocks produces four correct ciphertexts on four consecutive
cycles, each cross-checked against an independent software AES.

**Throughput** = 128 bits × f_clk. At 100 MHz that is **12.8 Gbit/s**.

> Area and f_max are not filled in yet — run Vivado synthesis + implementation for the PYNQ-Z2
> and record slice count and the achieved clock here, since the assignment grades on
> throughput, throughput × area, and initial latency.

---

## Running the simulation

Requires [Icarus Verilog](https://bleyer.org/icarus/) (`-g2012` is required).

```bash
cd "AES Pipelined"
iverilog -g2012 -o aes_obj \
    aes_sbox.v aes_subbytes.v aes_shiftrows.v aes_mixcolumns.v \
    aes128_key_expand_seq.v aes128_pipeline_seqkeys.v \
    tb_aes128_pipeline_seqkeys.v
vvp aes_obj
```

Expected output:

```
t=295000  Ciphertext=69c4e0d86a7b0430d8cdb78070b4c55a
```

For the baseline:

```bash
cd original
iverilog -g2012 -o orig_obj \
    SubTable.v SubBytes.v ShiftRows.v MixColumns.v \
    AddRoundKey.v KeyExpansion.v AESEncrypt.v test_AES128.v
vvp orig_obj    # note: this TB has no $finish — stop it with Ctrl-C
```

[test_AES128.v](original/test_AES128.v) drives the vector but never displays or checks the
result; inspect `out` in a waveform, or add `$display`/`$finish` on `done`.

---

## Known limitations

Worth resolving before FPGA implementation:

1. **`aes_sbox` is referenced hierarchically.** It is a port-less module whose function is called
   as `aes_sbox.fn(x)` from [aes_subbytes.v](AES%20Pipelined/aes_subbytes.v#L9) and
   [aes128_key_expand_seq.v](AES%20Pipelined/aes128_key_expand_seq.v#L36). Icarus accepts this
   (the module elaborates as a second top level), but **Vivado synthesis is likely to reject it.**
   For hardware, convert the S-box to a normal module with `in`/`out` ports, or move `fn` into a
   shared include file.

2. **Mixed blocking / non-blocking writes to `keys_out`.** The `write_rk` task assigns with `=`
   while the reset branch uses `<=` on the same register
   ([aes128_key_expand_seq.v](AES%20Pipelined/aes128_key_expand_seq.v#L43-L49)). Simulation is
   correct, but synthesis and lint tools will flag it.

3. **Do not reload the key while blocks are in flight.** `key_valid` drops `keys_ready`
   (and therefore `in_ready`), but the 11 stages already in the pipeline keep reading `keys_reg`,
   which switches to the new schedule the moment expansion completes — corrupting them. Let the
   pipeline drain before rekeying.

4. **Verilog-2001 declarations inside an unnamed block**
   ([aes128_key_expand_seq.v](AES%20Pipelined/aes128_key_expand_seq.v#L68)) require `-g2012`.

5. **`AES Pipelined/aes_obj` is a checked-in build artifact** (~455 KB of compiled `vvp` output)
   and should be removed and added to `.gitignore`.

---

## References

- NIST FIPS-197, *Advanced Encryption Standard (AES)* — test vectors from Appendix C.1
- Baseline AES implementation from HelloIITK, in [original/](original/)

## Disclaimer

Portions of the pipelined RTL in [AES Pipelined/](AES%20Pipelined/) were developed with AI
assistance, as permitted by the assignment brief. All functional verification against FIPS-197
vectors was performed on the code as committed.
