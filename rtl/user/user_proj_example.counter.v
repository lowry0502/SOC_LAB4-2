// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */
`timescale 1 ns / 1 ps
module user_proj_example #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wire wb_clk_i,
    input wire wb_rst_i,
    input wire wbs_stb_i,
    input wire wbs_cyc_i,
    input wire wbs_we_i,
    input wire [3:0] wbs_sel_i,
    input wire [31:0] wbs_dat_i,
    input wire [31:0] wbs_adr_i,
    output wire wbs_ack_o, // finish restore data from wishbone
    output wire [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input wire  [127:0] la_data_in,
    output wire [127:0] la_data_out,
    input wire  [127:0] la_oenb,

    // IOs
    input wire  [38-1:0] io_in,
    output wire [38-1:0] io_out,
    output wire [38-1:0] io_oeb,

    // IRQ
    output wire [2:0] irq
);

    //fireware bram
    wire clk;
    wire rst;

    wire EN0;
    wire [3:0] WE0;
    wire [31:0] A0;
    wire [31:0] Di0;
    wire [31:0] Do0;


    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // axi
    wire                        awready;
    wire                        wready;
    wire                         awvalid;
    wire   [(11): 0]  awaddr;
    wire                         wvalid;
    wire signed [(BITS-1) : 0] wdata;
    wire                        arready;
    wire                         rready;
    wire                         arvalid;
    wire         [(11): 0] araddr;
    wire                        rvalid;
    wire signed [(BITS-1): 0] rdata;

    wire                         ss_tvalid;
    wire signed [(BITS-1) : 0] ss_tdata;
    reg                         ss_tlast;
    wire                        ss_tready;
    wire                         sm_tready;
    wire                        sm_tvalid;
    wire signed [(BITS-1) : 0] sm_tdata;
    wire                        sm_tlast;

    reg                         axis_clk;
    wire                         axis_rst_n;

    //fir bram11 bram12
    wire                     tap_we;
    wire                     tap_re;
    wire [(BITS-1):0] tap_Di;
    wire [11:0] tap_A;
    wire [(BITS-1):0] tap_Do;

    wire                     data_we;
    wire                     data_re;
    wire [(BITS-1):0] data_Di;
    wire [(11):0] data_wA, data_rA;
    wire [(BITS-1):0] data_Do;

    //axi-lite
    assign axis_rst_n = !rst;
    assign awvalid =  (wbs_adr_i >= 32'h30000000) && (wbs_adr_i <= 32'h3000007F) && ( valid && wbs_we_i );
    assign wvalid = (wbs_adr_i >= 32'h30000000) && (wbs_adr_i <= 32'h3000007F) && (valid && wbs_we_i) ;
    assign wdata = wbs_dat_i;
    assign awaddr = wbs_adr_i;
    
    assign arvalid =  (wbs_adr_i >= 32'h30000000) && (wbs_adr_i <= 32'h3000007F) &&  (valid) && !wbs_we_i;
    assign rready = (wbs_adr_i >= 32'h30000000) && (wbs_adr_i <= 32'h3000007F) && ( valid ) ;
    assign araddr = wbs_adr_i; 
    
    //axi-stream

    assign ss_tvalid =  (wbs_adr_i == 32'h30000080) && ( valid && wbs_we_i );
    assign ss_tdata = wbs_dat_i;
    assign sm_tready = valid;

    //firmware bram
    
    assign EN0 =  (wbs_adr_i >= 32'h38000000) && (wbs_adr_i <= 32'h38400000) && (wbs_stb_i &&  wbs_cyc_i) ;
    assign A0 = wbs_adr_i - 32'h38000000;
    assign Di0 = wbs_dat_i;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; //responese wishbone 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = (wbs_adr_i >= 32'h38000000)? Do0: (wbs_adr_i >= 32'h30000000 && wbs_adr_i < 32'h30000080)? rdata: (wbs_adr_i >= 32'h30000084 && wbs_adr_i <= 32'h30000087)? sm_tdata: 32'hx ;
    assign wdata = wbs_dat_i;

    // IO
    //assign io_out = count;
    assign io_oeb = {(38-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    /*
    assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    */
    
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;


    counter #(
        .BITS(BITS)
    ) counter(
        .clk(clk),
        .reset(rst),
        .ready(wbs_ack_o),
        .valid(valid),
        .adr(wbs_adr_i),
        .wready(wready),
        .wbs_we_i(wbs_we_i),
        .rvalid(rvalid),
        .ss_tready(ss_tready),
        .sm_tvalid(sm_tvalid)
    );
    
    bram user_bram (
    .CLK(clk),
    .WE0(wstrb),
    .EN0(EN0),
    .Di0(Di0),
    .Do0(Do0),
    .A0(A0)
);

fir fir(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid), 
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),

        // ram for tap bram12
        .tap_we(tap_we),
        .tap_re(tap_re),
        .tap_waddr(tap_A),
        .tap_raddr(tap_A),
        .tap_wdi(tap_Di),
        .tap_wdo(tap_Do),

        // ram for data
        .data_we(data_we),
        .data_re(data_re),
        .data_waddr(data_wA),
        .data_raddr(data_rA),
        .data_wdi(data_Di),
        .data_wdo(data_Do),

        .axis_clk(clk),
        .axis_rst_n(axis_rst_n)

        );
    // RAM for tap
    bram12 tap_RAM (
        .clk(clk),
        .we(tap_we),
        .re(tap_re),
        .waddr(tap_A),
        .raddr(tap_A),
        .wdi(tap_Di),
        .rdo(tap_Do)
    );

    // RAM for data: choose bram11 or bram12
    bram11 data_RAM (
        .clk(clk),
        .we(data_we),
        .re(data_re),
        .waddr(data_wA),
        .raddr(data_rA),
        .wdi(data_Di),
        .rdo(data_Do)
    );

endmodule

module counter #(
    parameter BITS = 32
)(
    input wire clk,
    input wire reset,
    input wire valid,
    input wire [BITS-1:0] adr,
    input wire wready,
    input wire rvalid,
    input wire ss_tready,
    input wire sm_tvalid,
    input wire wbs_we_i,
    output reg ready
);
    

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            ready <= 0;
            i <= 0;
        end else begin
            ready <= 1'b0;
            if (valid && !ready  && adr >= 32'h38000000 && adr <= 32'h38400000) begin //firmware bram
                if(i == 10) begin
                    ready <= 1'b1;
                    i = 0;
                end
                i <= i + 1;
            end
            else if (valid && !ready  && adr >= 32'h30000000 && adr <= 32'h3000007F) begin //ap_signal
                if(wready && wbs_we_i ) begin
                    ready <= 1'b1;
                    i = 0;
                end
                else if(rvalid && !wbs_we_i ) begin
                    ready <= 1'b1;
                    i = 0;
                end
                i <= i + 1;
            end
            else if (valid && !ready  && adr >= 32'h30000080 && adr <= 32'h30000087) begin //ap_signal
                if(ss_tready && wbs_we_i  ) begin
                    ready <= 1'b1;
                    i = 0;
                end
                else if(sm_tvalid && !wbs_we_i  ) begin
                    ready <= 1'b1;
                    i = 0;
                end
                i <= i + 1;
            end
            else if (valid && !ready ) begin
                ready <= 1'b1;
            end
        end
    end

endmodule
`default_nettype wire
