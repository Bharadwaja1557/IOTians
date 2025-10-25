// AES-128 Key Expansion (sequential): produces rk0..rk10 over 11 cycles
module aes128_key_expand_seq (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         load,           // pulse 1 cycle with key_in stable
    input  wire [127:0] key_in,
    output reg          busy,
    output reg          done,           // 1-cycle pulse when finished
    output reg  [11*128-1:0] keys_out   // {rk0,rk1,...,rk10}, MSB=rk0
);
    reg [31:0] w0, w1, w2, w3;
    reg [3:0]  idx; // which rk just wrote (0..10)

    function [31:0] rcon(input [3:0] i);
        case (i)
            4'd1:  rcon = 32'h01000000;
            4'd2:  rcon = 32'h02000000;
            4'd3:  rcon = 32'h04000000;
            4'd4:  rcon = 32'h08000000;
            4'd5:  rcon = 32'h10000000;
            4'd6:  rcon = 32'h20000000;
            4'd7:  rcon = 32'h40000000;
            4'd8:  rcon = 32'h80000000;
            4'd9:  rcon = 32'h1b000000;
            4'd10: rcon = 32'h36000000;
            default: rcon = 32'h00000000;
        endcase
    endfunction

    function [31:0] rotword(input [31:0] x);
        rotword = {x[23:0], x[31:24]};
    endfunction

    function [31:0] subword(input [31:0] x);
        subword = {
            aes_sbox.fn(x[31:24]),
            aes_sbox.fn(x[23:16]),
            aes_sbox.fn(x[15:8]),
            aes_sbox.fn(x[7:0])
        };
    endfunction

    task write_rk(input [3:0] which, input [127:0] rk);
        integer bit_hi;
        begin
            bit_hi = (11*128-1) - which*128;
            keys_out[bit_hi -: 128] = rk;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w0 <= 0; w1 <= 0; w2 <= 0; w3 <= 0;
            idx <= 0;
            busy <= 1'b0;
            done <= 1'b0;
            keys_out <= {11*128{1'b0}};
        end else begin
            done <= 1'b0;

            if (load) begin
                {w0, w1, w2, w3} <= key_in;
                idx  <= 4'd0;
                busy <= 1'b1;
                write_rk(4'd0, key_in); // rk0
            end else if (busy) begin
                if (idx < 4'd10) begin
                    reg [31:0] t, nw0, nw1, nw2, nw3;
                    t   = subword(rotword(w3)) ^ rcon(idx + 4'd1);
                    nw0 = w0 ^ t;
                    nw1 = w1 ^ nw0;
                    nw2 = w2 ^ nw1;
                    nw3 = w3 ^ nw2;

                    w0 <= nw0; w1 <= nw1; w2 <= nw2; w3 <= nw3;

                    idx <= idx + 4'd1;
                    write_rk(idx + 4'd1, {nw0, nw1, nw2, nw3}); // rk1..rk10
                end else begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule
