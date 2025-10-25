`timescale 1ns/1ps
module tb_aes128_pipeline_seqkeys;
    reg         clk, rst_n;
    reg         in_valid;
    reg  [127:0] in_block;
    wire        in_ready;
    reg         key_valid;
    reg  [127:0] key;
    wire        keys_ready;
    wire        out_valid;
    wire [127:0] out_block;

    aes128_pipeline_seqkeys dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_block(in_block), .in_ready(in_ready),
        .key_valid(key_valid), .key(key), .keys_ready(keys_ready),
        .out_valid(out_valid), .out_block(out_block)
    );

    initial begin clk=0; forever #5 clk=~clk; end

    localparam [127:0] PT = 128'h00112233445566778899aabbccddeeff;
    localparam [127:0] K  = 128'h000102030405060708090a0b0c0d0e0f;

    initial begin
        rst_n=0; in_valid=0; key_valid=0; in_block=0; key=0;
        repeat(4) @(posedge clk);
        rst_n=1;

        // Load key (sequential expansion takes 11 cycles)
        @(posedge clk); key <= K; key_valid <= 1;
        @(posedge clk); key_valid <= 0;

        // Wait for keys_ready
        wait(keys_ready==1);

        // Send exactly one plaintext block (1-cycle in_valid)
        @(posedge clk);
        in_valid <= 1; in_block <= PT;
        @(posedge clk); in_valid <= 0;

        // Wait for the ciphertext and print it once
        wait(out_valid==1);
        $display("t=%0t  Ciphertext=%032x", $time, out_block);

        $finish;
    end
endmodule
