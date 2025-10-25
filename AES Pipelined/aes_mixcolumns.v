module aes_mixcolumns (
    input  wire [127:0] in,
    output wire [127:0] out
);
    function [7:0] xtime(input [7:0] x);
        xtime = {x[6:0],1'b0} ^ (8'h1b & {8{x[7]}});
    endfunction
    function [7:0] mul2(input [7:0] x); mul2 = xtime(x); endfunction
    function [7:0] mul3(input [7:0] x); mul3 = xtime(x) ^ x; endfunction

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : COL
            wire [7:0] b0 = in[127 - (32*c)      -: 8];
            wire [7:0] b1 = in[127 - (32*c + 8)  -: 8];
            wire [7:0] b2 = in[127 - (32*c + 16) -: 8];
            wire [7:0] b3 = in[127 - (32*c + 24) -: 8];

            wire [7:0] o0 = mul2(b0) ^ mul3(b1) ^ b2 ^ b3;
            wire [7:0] o1 = b0 ^ mul2(b1) ^ mul3(b2) ^ b3;
            wire [7:0] o2 = b0 ^ b1 ^ mul2(b2) ^ mul3(b3);
            wire [7:0] o3 = mul3(b0) ^ b1 ^ b2 ^ mul2(b3);

            assign out[127 - (32*c)      -: 8] = o0;
            assign out[127 - (32*c + 8)  -: 8] = o1;
            assign out[127 - (32*c + 16) -: 8] = o2;
            assign out[127 - (32*c + 24) -: 8] = o3;
        end
    endgenerate
endmodule
