

# 🖥️ 16x4 Synchronous RAM + ROM Combo in Verilog

This project presents the Verilog implementation of a **combined memory module** featuring a **16x4-bit synchronous single-port RAM** and a **16x4-bit ROM**. The design is fully synthesizable and targeted for FPGA implementation. It serves as a practical example of memory inference, synchronous design principles, and resource utilization analysis in a typical FPGA design flow.

The entire project, from RTL design and verification to synthesis and implementation, was completed using **AMD Vivado Design Suite**.

-----

## 📌 Core Features

  - **Dual Memory Architecture**: Integrates a 16-word, 4-bit wide RAM and a 16-word, 4-bit wide ROM into a single module with a shared interface.
  - **Synchronous Operation**: All read and write operations are synchronized to a rising-edge clock (`clk`), ensuring predictable timing.
  - **Parameterized ROM**: ROM contents are defined using parameters, allowing for easy customization at synthesis time without modifying the core logic.
  - **Inferred RAM**: The RAM is described behaviorally to allow synthesis tools to infer optimal on-chip memory resources (Distributed RAM).
  - **Write-First Policy**: For RAM write operations, the output port `dout` immediately reflects the new data being written, bypassing the read path for that cycle.
  - **Gated Logic**: A global enable signal (`en`) controls all operations, allowing the output to hold its state.

-----

## ⚙️ Module Interface and Operation

### Top-Level Ports

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk`  | Input     | 1     | System clock (rising-edge triggered) |
| `en`   | Input     | 1     | Active-high global enable for all operations |
| `sel`  | Input     | 1     | Memory select: **0 = ROM**, **1 = RAM** |
| `we`   | Input     | 1     | Active-high write enable (for RAM only) |
| `addr` | Input     | 4     | Address bus for both RAM and ROM (0 to 15) |
| `din`  | Input     | 4     | Data input bus for RAM writes |
| `dout` | Output    | 4     | Registered data output port |

### Functional Truth Table

This table describes the module's behavior when `en` is high. If `en=0`, `dout` holds its previous value regardless of other inputs.

| `sel` | `we` | Target Memory | Operation | `dout` After Next `posedge clk` |
|:-----:|:----:|:-------------:|-----------|---------------------------------|
| 0     | X    | ROM           | Read      | `ROM[addr]`                     |
| 1     | 0    | RAM           | Read      | `RAM[addr]`                     |
| 1     | 1    | RAM           | Write     | `din` (Write-First Behavior)    |

-----

## 🏛️ Architecture and Logic Explanation

The design consists of three main logical blocks: a combinational ROM, a sequential RAM, and a final selection multiplexer feeding a register stage.

1.  **ROM Block**: The 16x4 ROM is implemented as pure combinational logic using a series of ternary operators. The `addr` input directly selects one of the 16 pre-defined parameter values, which is then fed to the selection logic.
2.  **RAM Block**: The 16x4 RAM is described as a register array (`reg [3:0] ram [0:15];`). The logic is enclosed in a clocked `always` block, allowing the synthesis tool to infer it as on-chip distributed memory. The synchronous write operation is gated by both `sel` and `we`.
3.  **Output Stage**: A multiplexer, controlled by the `sel` signal, chooses between the output of the ROM (`rom_word`) and the RAM (`ram[addr]`). This selected value is then fed to the final output register `dout`. This registered output ensures a clean, synchronous output and prevents combinational delays from propagating to downstream modules.

### RTL Schematic

The post-synthesis schematic visualizes the hardware inferred by the Vivado tool. Key components are:

  - **IBUF/OBUF**: Input and output buffers for the FPGA pads.
  - **BUFG**: A global clock buffer for `clk` to ensure low-skew clock distribution.
  - **RAM32X1S**: The tool inferred four 32x1 single-port distributed RAM primitives to construct the 16x4 RAM. (It uses a 32-deep primitive because that's a standard LUTRAM size, and ties off the unused address bit).
  - **LUTs**: Look-Up Tables are used to implement the ROM logic and the final selection multiplexer.
  - **FDRE**: D-type flip-flops with clock enable are used for the registered output `dout`.

-----

## 📜 Source Code

The project consists of the core memory module and a dedicated testbench for verification.

\<details\>
\<summary\>\<strong\>Click to view Verilog Module: mem16x4\_combo.v\</strong\>\</summary\>

```verilog
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
                    ram[addr] <= din;   // write
                    dout      <= din;   // write-first
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
```

\</details\>

\<details\>
\<summary\>\<strong\>Click to view Testbench: tb\_mem16x4\_combo.v\</strong\>\</summary\>

```verilog
`timescale 1ns/1ps
module tb_mem16x4_combo;
    reg         clk=0, en=0, sel=0, we=0;
    reg  [3:0]  addr=0, din=0;
    wire [3:0]  dout;

    // Instantiate with a custom ROM pattern for testing
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

    always #5 clk = ~clk; // 10ns clock period

    initial begin
        // 1) Read ROM at multiple addresses
        en <= 1;
        sel <= 0;
        we <= 0;
        addr <= 4'd0; @(posedge clk);
        addr <= 4'd3; @(posedge clk);
        addr <= 4'd10; @(posedge clk);

        // 2) Write RAM and read back
        sel <= 1;
        addr <= 4'd5; din <= 4'h9; we <= 1; @(posedge clk); // Write
        we <= 0; @(posedge clk); // Read back

        // 3) Verify ROM is unaffected
        sel <= 0; @(posedge clk); // Read ROM at addr 5

        // 4) Verify enable behavior
        en <= 0;
        addr <= 4'd1; @(posedge clk); // Try to read ROM, but dout should hold

        #20;
        $finish;
    end
endmodule
```

\</details\>

-----

## 🧪 Verification and Simulation

The design was verified using the provided testbench, which covers the following scenarios:

1.  **ROM Read**: Reads from multiple ROM addresses to check for correctness.
2.  **RAM Write/Read**: Writes a value to a RAM address and reads it back to verify data integrity.
3.  **Memory Isolation**: Confirms that writing to a RAM address does not corrupt the data in the ROM at the same address.
4.  **Enable Functionality**: Tests that de-asserting `en` causes the output `dout` to hold its state.

### Simulation Waveform Analysis

The waveform below, generated from the testbench, confirms correct logical operation.

  - **0-30 ns**: `sel=0` (ROM mode). The testbench cycles through addresses `0`, `3`, and `10`. The output `dout` correctly shows the expected ROM values (`A`, `D`, `7`) one clock cycle after each address change.
  - **30-50 ns**: `sel=1` (RAM mode).
      - At the clock edge near 40 ns, `we=1`, `addr=5`, and `din=9`. A write operation occurs. `dout` immediately becomes `9`, demonstrating the write-first behavior.
      - At the clock edge near 50 ns, `we=0`. A read operation from `addr=5` is performed, and `dout` correctly reads the stored value, `9`.
  - **50-60 ns**: `sel=0` again. The testbench reads from `addr=5`. `dout` correctly outputs the ROM value `2`, proving the RAM write did not affect the ROM.
  - **60-80 ns**: `en` is de-asserted to `0`. Although the address changes to `1`, `dout` holds its previous value of `2`, confirming the enable logic works correctly.

-----

## 🔬 Synthesis and Implementation Results

The Verilog code was synthesized and implemented on a Xilinx FPGA using Vivado. The following reports summarize the results.

### Tool Flow and Logs

The synthesis and implementation processes were run successfully without critical warnings or errors, as shown in the tool logs.

| Synthesis Log Snippet | TCL Console Log |
| :---: | :---: |
|  |  |

### Resource Utilization

The design is lightweight and consumes minimal FPGA resources. The synthesis tool correctly inferred the behavioral RAM as 4 instances of `RAM16X1S` (16x1 Single Port RAM), which are implemented using LUTs (as LUTRAM).

  - **LUTs**: 5 (1 for ROM logic, 4 for RAM)
  - **Flip-Flops (FDRE)**: 4 (for the `dout` register)
  - **Buffers**: 12 IBUF, 4 OBUF, 1 BUFG

### Timing Analysis

No timing constraints (clock period, I/O delays) were provided, so the tool did not perform a constrained timing analysis. The reported slack is infinite, indicating all paths are analyzed as unconstrained. For a real-world application, a `create_clock` constraint would be added.

### Power Analysis

The power analysis estimates a **Total On-Chip Power of 1.663 W**. The breakdown shows that the vast majority (94%) of this power is consumed by I/O, which is typical for small designs where static power and internal logic switching are minimal compared to driving external pins.

### Physical Implementation (Device View)

The images below show the final placement of the synthesized logic on the FPGA fabric. This view confirms the physical realization of the design, with logic elements placed and routed by the tool.

| Device View (Zoomed Out) | Device View (Zoomed In) |
|:---:|:---:|
|  |  |

-----

## 🚀 Applications

  - **Educational Tool**: Excellent for teaching memory architecture, synchronous design, and FPGA synthesis concepts.
  - **Prototyping**: Can be used as a small scratchpad memory or lookup table in larger FPGA projects.
  - **Microcontroller IP**: Serves as a basic memory block for custom, small-scale processor designs.
  - **FPGA-based System-on-Chip (SoC)**: Could be integrated as a configuration register bank or a small data buffer.
