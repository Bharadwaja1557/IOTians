module aes_shiftrows (
    input  wire [127:0] in,
    output wire [127:0] out
);
    wire [7:0] s [0:15];
    genvar i;
    generate for (i = 0; i < 16; i = i + 1) begin : UNP
        assign s[i] = in[127 - 8*i -: 8];
    end endgenerate

    // Row 0
    assign out[127:120] = s[0];
    assign out[95:88]   = s[4];
    assign out[63:56]   = s[8];
    assign out[31:24]   = s[12];

    // Row 1 (left 1)
    assign out[119:112] = s[5];
    assign out[87:80]   = s[9];
    assign out[55:48]   = s[13];
    assign out[23:16]   = s[1];

    // Row 2 (left 2)
    assign out[111:104] = s[10];
    assign out[79:72]   = s[14];
    assign out[47:40]   = s[2];
    assign out[15:8]    = s[6];

    // Row 3 (left 3)
    assign out[103:96]  = s[15];
    assign out[71:64]   = s[3];
    assign out[39:32]   = s[7];
    assign out[7:0]     = s[11];
endmodule
