# Baseline AES-128 (original)

The unmodified HelloIITK AES-128 implementation that [PipeAES-128](../README.md) started from,
kept here for comparison.

**Iterative design:** one AES round per clock, folded onto a single round of hardware.
[AESEncrypt.v](AESEncrypt.v) walks `roundCount` from 1 to 11, selecting the matching round key
each cycle. The full key schedule is generated **combinationally** by
[KeyExpansion.v](KeyExpansion.v) — ten chained `KeyExpansionRound` instances, which is the long
critical path the pipelined rewrite exists to remove.

- ~11 cycles per block, one block in flight at a time
- `KeyExpansion` is parameterised over `Nk`/`Nr`, so it also covers AES-192/256

| File | Role |
|---|---|
| [AESEncrypt.v](AESEncrypt.v) | Round FSM + `AESEncrypt128_DUT` wrapper |
| [KeyExpansion.v](KeyExpansion.v) | Combinational key schedule |
| [SubBytes.v](SubBytes.v) / [SubTable.v](SubTable.v) | Byte substitution + S-box table |
| [ShiftRows.v](ShiftRows.v) | Row rotations |
| [MixColumns.v](MixColumns.v) | GF(2⁸) column mixing |
| [AddRoundKey.v](AddRoundKey.v) | State ⊕ round key |
| [test_AES128.v](test_AES128.v) | Testbench (drives the FIPS-197 vector; no self-check or `$finish`) |

```bash
iverilog -g2012 -o orig_obj \
    SubTable.v SubBytes.v ShiftRows.v MixColumns.v \
    AddRoundKey.v KeyExpansion.v AESEncrypt.v test_AES128.v
vvp orig_obj
```
