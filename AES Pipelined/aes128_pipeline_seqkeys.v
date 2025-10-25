// AES-128 Encryptor: datapath fully pipelined, key expansion sequential
module aes128_pipeline_seqkeys (
    input  wire         clk,
    input  wire         rst_n,          // active-low reset

    // Data in
    input  wire         in_valid,
    input  wire [127:0] in_block,
    output wire         in_ready,       // high only when keys are ready

    // Key load
    input  wire         key_valid,      // pulse 1 cycle to (re)load key
    input  wire [127:0] key,
    output wire         keys_ready,     // high when rk0..rk10 available

    // Data out
    output wire         out_valid,
    output wire [127:0] out_block
);
    // --- Sequential key expansion ---
    wire [11*128-1:0] keys_packed;
    wire              kexp_busy, kexp_done;

    aes128_key_expand_seq u_kexp (
        .clk      (clk),
        .rst_n    (rst_n),
        .load     (key_valid),
        .key_in   (key),
        .busy     (kexp_busy),
        .done     (kexp_done),
        .keys_out (keys_packed)
    );

    reg [11*128-1:0] keys_reg;
    reg              keys_reg_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            keys_reg       <= {11*128{1'b0}};
            keys_reg_valid <= 1'b0;
        end else begin
            if (kexp_done) begin
                keys_reg       <= keys_packed;
                keys_reg_valid <= 1'b1;
            end
            if (key_valid) begin
                keys_reg_valid <= 1'b0; // will refill
            end
        end
    end

    assign keys_ready = keys_reg_valid;

    // Unpack keys rk[0..10]
    wire [127:0] rk [0:10];
    genvar ki;
    generate
        for (ki = 0; ki < 11; ki = ki + 1) begin : UNPACK
            assign rk[ki] = keys_reg[(11*128-1) - ki*128 -: 128];
        end
    endgenerate

    // --- 11-stage data pipeline (ARK0 | 9 rounds | final round) ---
    reg [127:0] stage_state [0:10];
    reg         stage_valid [0:10];

    assign in_ready = keys_ready;
    wire accept = in_valid & in_ready;

    integer si;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (si = 0; si < 11; si = si + 1) begin
                stage_state[si] <= 128'd0;
                stage_valid[si] <= 1'b0;
            end
        end else begin
            // Stage 0: initial AddRoundKey
            stage_state[0] <= in_block ^ rk[0];
            stage_valid[0] <= accept;

            // Stages 1..9: SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
            stage_state[1]  <= round_full_state[1];
            stage_valid[1]  <= stage_valid[0];

            stage_state[2]  <= round_full_state[2];
            stage_valid[2]  <= stage_valid[1];

            stage_state[3]  <= round_full_state[3];
            stage_valid[3]  <= stage_valid[2];

            stage_state[4]  <= round_full_state[4];
            stage_valid[4]  <= stage_valid[3];

            stage_state[5]  <= round_full_state[5];
            stage_valid[5]  <= stage_valid[4];

            stage_state[6]  <= round_full_state[6];
            stage_valid[6]  <= stage_valid[5];

            stage_state[7]  <= round_full_state[7];
            stage_valid[7]  <= stage_valid[6];

            stage_state[8]  <= round_full_state[8];
            stage_valid[8]  <= stage_valid[7];

            stage_state[9]  <= round_full_state[9];
            stage_valid[9]  <= stage_valid[8];

            // Stage 10: final SubBytes -> ShiftRows -> AddRoundKey
            stage_state[10] <= final_round_state;
            stage_valid[10] <= stage_valid[9];
        end
    end

    // Combinational per-stage round logic
    wire [127:0] sb_wire [1:10];
    wire [127:0] sr_wire [1:10];
    wire [127:0] mc_wire [1:9];

    genvar r;
    generate
        for (r = 1; r <= 9; r = r + 1) begin : GEN_ROUNDS
            aes_subbytes   u_sb (.in(stage_state[r-1]), .out(sb_wire[r]));
            aes_shiftrows  u_sr (.in(sb_wire[r]),       .out(sr_wire[r]));
            aes_mixcolumns u_mc (.in(sr_wire[r]),       .out(mc_wire[r]));
        end
    endgenerate

    aes_subbytes  u_sb_final (.in(stage_state[9]),  .out(sb_wire[10]));
    aes_shiftrows u_sr_final (.in(sb_wire[10]),     .out(sr_wire[10]));

    // Add round key
    wire [127:0] round_full_state [1:9];
    generate
        for (r = 1; r <= 9; r = r + 1) begin : GEN_ARK
            assign round_full_state[r] = mc_wire[r] ^ rk[r];
        end
    endgenerate

    wire [127:0] final_round_state = sr_wire[10] ^ rk[10];

    assign out_block = stage_state[10];
    assign out_valid = stage_valid[10];
endmodule
