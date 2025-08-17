`timescale 1ns/1ps
module tb_mem16x4_combo;
    reg         clk=0, en=0, sel=0, we=0;
    reg  [3:0]  addr=0, din=0;
    wire [3:0]  dout;

    // Instantiate with known ROM pattern
   // Instantiate with known ROM pattern
    mem16x4_combo #(
        .ROM0(4'hA), .ROM1(4'hB), .ROM2(4'hC), .ROM3(4'hD),
        .ROM4(4'h1), .ROM5(4'h2), .ROM6(4'h3), .ROM7(4'h4),
        .ROM8(4'h5), .ROM9(4'h6), .ROM10(4'h7), .ROM11(4'h8),
        .ROM12(4'h9), .ROM13(4'h0), .ROM14(4'hE), .ROM15(4'hF)
    ) dut (
        .clk(clk), 
        .en(en), 
        .sel(sel), 
        .we(we), 
        .addr(addr), 
        .din(din), 
        .dout(dout)
    );
    always #5 clk = ~clk;

    task tick; begin @(negedge clk); @(posedge clk); end endtask

    initial begin
        // Enable
        en <= 1;

        // 1) Read ROM at a few addresses
        sel<=0; we<=0;
        addr<=4'd0;  tick; // expect A
        addr<=4'd3;  tick; // expect D
        addr<=4'd10; tick; // expect 7

        // 2) Write RAM and read back
        sel<=1;
        // write addr=5 data=0x9
        addr<=4'd5; din<=4'h9; we<=1; tick; // dout=9 (write-first)
        // read addr=5
        we<=0;                         tick; // dout=9

        // 3) ROM unaffected by RAM writes
        sel<=0; addr<=4'd5; tick; // expect ROM5=2

        // 4) Hold behavior when en=0
        en<=0; addr<=4'd1; sel<=0; tick; // dout holds previous value

        #10; // Wait a moment before finishing to see final output
        $finish;
    end
endmodule