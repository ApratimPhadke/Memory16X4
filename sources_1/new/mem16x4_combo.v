`timescale 1ns/1ps
`default_nettype none

// 16x4 ROM + 16x4 RAM combined
module mem16x4_combo #(
    // ROM contents per address 0..15 (nibble each). Change defaults as needed.
    parameter [3:0] ROM0  = 4'h0, parameter [3:0] ROM1  = 4'h1,
    parameter [3:0] ROM2  = 4'h2, parameter [3:0] ROM3  = 4'h3,
    parameter [3:0] ROM4  = 4'h4, parameter [3:0] ROM5  = 4'h5,
    parameter [3:0] ROM6  = 4'h6, parameter [3:0] ROM7  = 4'h7,
    parameter [3:0] ROM8  = 4'h8, parameter [3:0] ROM9  = 4'h9,
    parameter [3:0] ROM10 = 4'hA, parameter [3:0] ROM11 = 4'hB,
    parameter [3:0] ROM12 = 4'hC, parameter [3:0] ROM13 = 4'hD,
    parameter [3:0] ROM14 = 4'hE, parameter [3:0] ROM15 = 4'hF
)(
    input  wire        clk,    // rising-edge clock
    input  wire        en,     // enable (gates read/write and output register)
    input  wire        sel,    // 0 = ROM, 1 = RAM
    input  wire        we,     // write enable (only when sel=1)
    input  wire [3:0]  addr,   // address 0..15
    input  wire [3:0]  din,    // data in  (RAM only)
    output reg  [3:0]  dout    // registered data out
);
    // 16x4 RAM
    reg [3:0] ram [0:15];

    // Combinational ROM word selected by address
    wire [3:0] rom_word;
    assign rom_word = (addr==4'd0 ) ? ROM0  :
                      (addr==4'd1 ) ? ROM1  :
                      (addr==4'd2 ) ? ROM2  :
                      (addr==4'd3 ) ? ROM3  :
                      (addr==4'd4 ) ? ROM4  :
                      (addr==4'd5 ) ? ROM5  :
                      (addr==4'd6 ) ? ROM6  :
                      (addr==4'd7 ) ? ROM7  :
                      (addr==4'd8 ) ? ROM8  :
                      (addr==4'd9 ) ? ROM9  :
                      (addr==4'd10) ? ROM10 :
                      (addr==4'd11) ? ROM11 :
                      (addr==4'd12) ? ROM12 :
                      (addr==4'd13) ? ROM13 :
                      (addr==4'd14) ? ROM14 : ROM15;

    // Synchronous behavior
    always @(posedge clk) begin
        if (en) begin
            if (sel) begin
                // Targeting RAM
                if (we) begin
                    ram[addr] <= din;    // write
                    dout      <= din;    // write-first
                end else begin
                    dout      <= ram[addr]; // read
                end
            end else begin
                // Targeting ROM (read-only)
                dout <= rom_word;
            end
        end
        // if en=0, hold last dout value
    end

endmodule

`default_nettype wire
