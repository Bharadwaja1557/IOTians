module aes_subbytes (
    input  wire [127:0] in,
    output wire [127:0] out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : SB
            wire [7:0] b_in  = in [127 - 8*i -: 8];
            wire [7:0] b_out = aes_sbox.fn(b_in);
            assign out[127 - 8*i -: 8] = b_out;
        end
    endgenerate
endmodule
