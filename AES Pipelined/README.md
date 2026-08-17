# AES Pipelined

The pipelined AES-128 core — 11-stage unrolled datapath with a sequential key schedule.
One ciphertext block per clock cycle after an 11-cycle fill.

| File | Role |
|---|---|
| [aes128_pipeline_seqkeys.v](aes128_pipeline_seqkeys.v) | Top level — 11 pipeline stages + valid shift |
| [aes128_key_expand_seq.v](aes128_key_expand_seq.v) | Sequential key expansion, rk0..rk10 over 11 cycles |
| [aes_subbytes.v](aes_subbytes.v) | 16 parallel S-box lookups |
| [aes_shiftrows.v](aes_shiftrows.v) | Row rotations (pure rewiring) |
| [aes_mixcolumns.v](aes_mixcolumns.v) | GF(2⁸) column mixing |
| [aes_sbox.v](aes_sbox.v) | 256-byte S-box table + lookup function |
| [tb_aes128_pipeline_seqkeys.v](tb_aes128_pipeline_seqkeys.v) | Testbench, FIPS-197 vector |

Build and run:

```bash
iverilog -g2012 -o aes_obj \
    aes_sbox.v aes_subbytes.v aes_shiftrows.v aes_mixcolumns.v \
    aes128_key_expand_seq.v aes128_pipeline_seqkeys.v \
    tb_aes128_pipeline_seqkeys.v
vvp aes_obj
# t=295000  Ciphertext=69c4e0d86a7b0430d8cdb78070b4c55a
```

See the [top-level README](../README.md) for architecture, results, and known limitations.
