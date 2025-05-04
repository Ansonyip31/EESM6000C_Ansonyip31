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

`define MPRJ_IO_PADS_1 19	/* number of user GPIO pads on user1 side */
`define MPRJ_IO_PADS_2 19	/* number of user GPIO pads on user2 side */
`define MPRJ_IO_PADS (`MPRJ_IO_PADS_1 + `MPRJ_IO_PADS_2)


`default_nettype wire
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

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10,
    parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  wire  [`MPRJ_IO_PADS-1:0] io_in,
    output wire  [`MPRJ_IO_PADS-1:0] io_out,
    output wire[`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);

    wire clk;
    wire rst;
    assign clk = wb_clk_i;
    assign rst = wb_rst_i;

    // wire [`MPRJ_IO_PADS-1:0] io_in;
    // wire [`MPRJ_IO_PADS-1:0] io_out;
    // wire [`MPRJ_IO_PADS-1:0] io_oeb;

    // Address Decode
    wire [1:0] decode;
    assign decode = (wbs_adr_i[31:16]==16'h3800) ? 2'd2:    // exmem_fir
                    (wbs_adr_i[31:16]==16'h3000) ? 2'd1: 2'd0;   // veilog_fir


    wire exmem_req, fir_req;    // 3800 , 3000
    assign exmem_req 	= wbs_cyc_i & wbs_stb_i & (decode == 2'd2);
    assign fir_req = wbs_cyc_i & wbs_stb_i & (decode == 2'd1);

    // write data to on_chip ram only when req_sig assert
    wire [31:0] ram_adr;
    wire [31:0] ram_data;
    wire [3:0] ram_we;
    wire ram_en;

    assign ram_adr  = {32{exmem_req}} & wbs_adr_i;
    assign ram_data = {32{exmem_req}} & wbs_dat_i ;
    assign ram_we   = {4 {exmem_req}} & {4{wbs_we_i}} & wbs_sel_i ;
    assign ram_en   =     exmem_req   & wbs_cyc_i     & wbs_sel_i;

    wire                     awready;       // o
    wire                     wready;        // o
    wire                     awvalid;       // i
    wire [(pADDR_WIDTH-1):0] awaddr;        // i
    wire                     wvalid;        // i 
    wire [(pDATA_WIDTH-1):0] wdata;         // i
    wire                     arready;       // o
    wire                     rready;        // i
    wire                     arvalid;       // i
    wire [(pADDR_WIDTH-1):0] araddr;        // i
    wire                     rvalid;        // o 
    wire [(pDATA_WIDTH-1):0] rdata;         // o
    wire                     ss_tvalid;     // i
    wire [(pDATA_WIDTH-1):0] ss_tdata;      // i
    wire                     ss_tlast;      // i
    wire                     ss_tready;     // o
    wire                     sm_tready;     // i
    wire                     sm_tvalid;     // o
    wire [(pDATA_WIDTH-1):0] sm_tdata;      // o
    wire                     sm_tlast;      // o
    wire                     axis_clk;
    wire                     axis_rst_n;

    // bram for tap RAM
    wire           [3:0]     tap_WE;
    wire                     tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    wire [(pDATA_WIDTH-1):0] tap_Do;     // i

    // bram for data RAM
    wire            [3:0]    data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    wire [(pDATA_WIDTH-1):0] data_Do;   // i

    wire tap_in_req, data_length_in_req, ctrl_in_req;
    wire x_in_req, y_out_req;
    reg [(pDATA_WIDTH-1):0] data_length, data_length_count;
    
    assign axis_clk = wb_clk_i;
    assign axis_rst_n = !wb_rst_i;
    
    assign tap_in_req = 		(fir_req && wbs_adr_i[7:0] >= 8'h40 && wbs_adr_i[7:0] <= 8'h7F);
    assign x_in_req = 			(fir_req && wbs_adr_i[7:0] >= 8'h80 && wbs_adr_i[7:0] <= 8'h83);
    assign y_out_req = 		(fir_req && wbs_adr_i[7:0] >= 8'h84 && wbs_adr_i[7:0] <= 8'h87);
    assign data_length_in_req = 	(fir_req && wbs_adr_i[7:0] >= 8'h10 && wbs_adr_i[7:0] <= 8'h13);
    assign ctrl_in_req = 		(fir_req && wbs_adr_i[7:0] == 8'h00 );

    wire write_req;
    wire read_req;
    wire ss_req;
    assign write_req = (ctrl_in_req || tap_in_req ||  data_length_in_req)& wbs_we_i;
    
    assign awvalid   = write_req ;
    assign awaddr    = {pADDR_WIDTH{write_req}} &  wbs_adr_i ;

    assign wvalid    = write_req;
    assign wdata     = {32{write_req}} & wbs_dat_i  ;

    assign read_req  = (!wbs_we_i & tap_in_req );
    assign rready    = read_req;
    assign arvalid   = read_req;
    assign araddr    = {pADDR_WIDTH{read_req}} & wbs_adr_i;

    assign ss_req = (wbs_we_i & x_in_req);
    assign ss_tlast  = (data_length_count==(data_length-1)) ;
    assign ss_tvalid = ss_req ;
    assign ss_tdata  = {32{ss_req}} & wbs_dat_i ;
    assign sm_tready = fir_req;

    wire fir_ack_o;
    wire exmem_ack_o;
    wire [31:0] exmem_fir_o;
    reg [3:0] exmem_counter;   
    
    always @ (posedge clk) begin 
    	if(rst)begin
    		exmem_counter <= 4'b0;
    	end else begin 
    		if (exmem_req)begin 
    			if(exmem_counter != DELAYS)begin
    				exmem_counter <= exmem_counter +4'b1;
    			end else begin 
    				exmem_counter <= 32'b0;
    			end 
    		end else begin
    			exmem_counter <=32'b0;
    		end 
    	end 
    end
    
    assign exmem_ack_o = exmem_counter == DELAYS;	
    assign fir_ack_o = (awready && wready) ||
    			(rvalid) ||
    			(data_length_in_req && awready) || 
        		(ctrl_in_req && awready) ||
        		(sm_tvalid) ||
        		(y_out_req) ;
        
    assign wbs_ack_o =  fir_ack_o | exmem_ack_o;
    	
    reg [(pDATA_WIDTH-1):0] data_y;
    always @ (posedge wb_clk_i) begin 
        if (wb_rst_i)
            data_y <= 32'b0;
        else if (sm_tvalid)
            data_y <= sm_tdata;
    end

    assign wbs_dat_o = (exmem_ack_o)? exmem_fir_o :
                    	(y_out_req)? data_y : 
                    	(fir_ack_o)? sm_tdata : 1'b0 ;


    always@(posedge wb_clk_i)begin
        if(wb_rst_i) 
            data_length_count <= {pDATA_WIDTH{1'b0}};		
        else if(data_length_in_req) 
            data_length <= wbs_dat_i;
        else if(sm_tvalid==1'b1) 
            data_length_count <= data_length_count + 1;
        else if (sm_tlast) 
            data_length_count <= {pDATA_WIDTH{1'b0}};
    end

wire [1:0] state;
wire ap_start_sig, ss_write_valid;
wire ctrl_tap_ready, ctrl_tap_valid;

fir u_fir(
        .awready(awready),          // o
        .wready(wready),            // o
        .awvalid(awvalid),          // i
        .awaddr(awaddr),            // i
        .wvalid(wvalid),            // i
        .wdata(wdata),              // i
        .arready(arready),          // o
        .rready(rready),            // i
        .arvalid(arvalid),          // i
        .araddr(araddr),            // i
        .rvalid(rvalid),            // o
        .rdata(rdata),              // o
        .ss_tvalid(ss_tvalid),      // i
        .ss_tdata(ss_tdata),        // i
        .ss_tlast(ss_tlast),        // i
        .ss_tready(ss_tready),      // o
        .sm_tready(sm_tready),      // i
        .sm_tvalid(sm_tvalid),      // o
        .sm_tdata(sm_tdata),        // o
        .sm_tlast(sm_tlast),        // o

        // ram for tap
        .tap_WE(tap_WE),            // o
        .tap_EN(tap_EN),            // o
        .tap_Di(tap_Di),            // o        
        .tap_Do(tap_Do),            // i
        .tap_A(tap_A),              // o

        // ram for data
        .data_WE(data_WE),          // o
        .data_EN(data_EN),          // o
        .data_Di(data_Di),          // o        
        .data_Do(data_Do),          // i
	.data_A(data_A),            // o
	
        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n),
        .state(state),
        .ap_start_sig(ap_start_sig),        
        .ctrl_tap_valid(ctrl_tap_valid),
        .ctrl_tap_ready(ctrl_tap_ready),
        .ss_write_valid(ss_write_valid)
    );             


bram u_exmem_bram(
    .CLK(clk),
    .WE0(ram_we),
    .EN0(ram_en),
    .Di0(ram_data),
    .Do0(exmem_fir_o),
    .A0(ram_adr)
);

// RAM for tap
bram11 u_tap_RAM (
           .CLK(axis_clk),
           .WE(tap_WE),
           .EN(tap_EN),
           .Di(tap_Di),
           .Do(tap_Do),
           .A(tap_A)
       );

// RAM for data: choose bram11 or bram12
bram11 u_data_RAM(
           .CLK(axis_clk),
           .WE(data_WE),
           .EN(data_EN),
           .Di(data_Di),           
           .Do(data_Do),
           .A(data_A)
       );      


endmodule


`default_nettype wire
