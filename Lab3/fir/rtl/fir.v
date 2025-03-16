module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
reg [1:0] ns_state;
wire [1:0] cs_state;

reg [3:0] ns_wait_data_cnt;
wire [3:0] cs_wait_data_cnt;

reg[9:0] ns_data_out_cnt;
wire[9:0] cs_data_out_cnt;

reg [3:0] ns_tap_addr_cnt;
wire [3:0] cs_tap_addr_cnt;

reg[31:0]ns_res;
wire[31:0]cs_res;

wire [2:0] ns_ap_ctrl;
wire [2:0] cs_ap_ctrl;

wire[31:0] ns_data_length;
wire[31:0] cs_data_length;

wire ns_rvalid;
wire cs_rvalid;
assign rvalid=cs_rvalid;

// write your code here!
dffr #(.WIDTH(2)) u_dffr_axis_fsm (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_state) , .q(cs_state));
dffr #(.WIDTH(4)) u_dffr_wait_data_cnt (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_wait_data_cnt) , .q(cs_wait_data_cnt));
dffr #(.WIDTH(4)) u_dffr_data_acc (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_data_acc) , .q(cs_data_acc));
dffr #(.WIDTH(10)) u_dffr_data_out_cnt (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_data_out_cnt) , .q(cs_data_out_cnt));
dffr #(.WIDTH(4)) u_dffr_tap_addr_cnt (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_tap_addr_cnt) , .q(cs_tap_addr_cnt));
dffr #(.WIDTH(32)) u_dffr_res (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_res) , .q(cs_res));
dffr #(.WIDTH(1)) u_dffr_tap_addr_cnt (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_rvalid) , .q(cs_rvalid));
parameter IDLE=2'd0, WAIT_IN=2'd1, CAL=2'd2, WAIT_OUT=2'd3;
always@(*)begin
    case(cs_state)
        IDLE: begin 
            if(cs_ap_ctrl==3'b101)begin 
                ns_state =WAIT_IN;
                ns_wait_data_cnt=cs_wait_data_cnt;
            end else begin 
            if (awaddr==12'h40)begin 
                ns_wait_data_cnt = cs_wait_data_cnt+4'b1;
            end else begin 
            if (awaddr==12'h0 && cs_wait_data_cnt !=0)begin
                ns_wait_data_cnt = (cs_wait_data_cnt==4'ha)?4'b0:cs_wait_data_cnt+4'b1;
            end else begin 
                ns_wait_data_cnt=cs_wait_data_cnt;
            end 
            end 
            end 
        end 
        WAIT_IN: begin 
            ns_state=(ss_tvalid & ss_tready)?CAL :WAIT_IN;
        end 
        CAL:begin 
            ns_wait_data_cnt = cs_wait_data_cnt+4'b1;
            if(cs_data_out_cnt<=10'ha )begin
                if(cs_data_out_cnt==cs_data_acc)begin 
                    ns_data_acc=cs_data_acc;
                    ns_state=CAL;
                    ns_wait_data_cnt= cs_wait_data_cnt+4'b1;
                if(cs_wait_data_cnt==cs_data_out_cnt+10'd2)begin
                    ns_data_acc ==4'b0;
                    ns_state    ==WAIT_OUT;
                    ns_wait_data_cnt =4'b0;
                end
                end else begin 
                ns_data_acc =cs_data_acc +4'b1;
                ns_state=CAL;
                ns_wait_data_cnt=cs_wait_data_cnt=4'b1;
                end 
            end else if(cs_data_out_cnt> 10'ha)begin 
                ns_data_acc = (cs_wait_data_cnt ==4'hc)?4'b0:
                              (cs_data_acc ==4'ha)? cs_data_acc:
                              cs_data_acc+4'b1;
                ns_wait_data_cnt =(cs_wait_data_cnt==4'hc)?0:cs_wait_data_cnt+4'b1;
                ns_state = (cs_wait_data_cnt==4'hc)?WAIT_OUT:CAL;
                if(cs_tap_addr_cnt==4'b0)begin
                    ns_tap_addr_cnt=4'ha;
                    if(cs_wait_data_cnt>4'ha)begin 
                        ns_tap_addr_cnt=cs_tap_addr_cnt;
                    end
                end
                else begin 
                        ns_tap_addr_cnt=cs_tap_addr_cnt-4'b1;
            end  
            end
        end 
        WAIT_OUT: begin 
                ns_state=(sm_tready&&sm_tvalid)?(cs_data_out_cnt==cs_data_length-32'b1)?10'b0:cs_data_cnt+10'b1:cs_data_out_cnt;
        end
    endcase 
end 
dffr #(.WIDTH(2)) u_dffr_ap_ctrl (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_ap_ctrl[1:0]) , .q(cs_ap_ctrl[1:0]));
dffs #(.WIDTH(1)) u_dffs_ap_ctrl (.clk(axis_clk),.rst_n(axis_rst_n),.d(ns_ap_ctrl[2]),.q(cs_ap_ctrl[2]));
dffr #(.WIDTH(32)) u_dffr_data_length (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_data_length) , .q(cs_data_length));
always @(*)begin 
    if(cs_state==IDLE)begin 
        if(awaddr=12'h0)begin 
            if(cs_ap_ctrl[2]&!cs_ap_ctrl[0])
                ns_ap_ctrl ={cs_ap_ctrl[2],1'b0,wdata[0]};
            else if (cs_ap_ctrl[0]==1'b1)
                ns_ap_ctrl ={1'b0,cs_ap_ctrl[1:0]};
        end 
    end else if(cs_state==WAIT_IN)begin 
            if(ss_tvalid &7 ss_tready && cs_ap_ctrl[0]==1)begin
                ns_ap_ctrl<=3'b0;
            end 
    end else if(cs_state==WAIT_OUT)begin
            if((cs_data_out_cnt==cs_data_length-1)&sm_tready&sm_tvalid)begin    
                ns_ap_ctrl={1'b1,1'b1,cs_ap_ctrl[0]}
            end 
    end 
end 
always @(*)begin 
    if(cs_state==IDLE)begin 
        if(awaddr=12'h0)begin 
            if (cs_ap_ctrl[0]==1'b1)
                ns_data_length =wdata;
        end 
    end
end 
 always @(*) begin
        case(cs_state)
            IDLE: begin
                rdata = (rvalid && araddr >= 12'h40) ? tap_Do : 32'd0;
            end
            WAIT_IN: begin
                rdata = (rvalid && araddr == 12'h00) ? {26'b0, (cs_state==WAIT_OUT), (cs_state==WAIT_IN), 1'b0, cs_ap_ctrl[2:0]} : 32'd0;
            end
            default: rdata = 0;
        endcase
end
 always @(*) begin
        case(cs_state)
            IDLE: begin
                arready = (awaddr >= 12'h40 && araddr >= 12'h40) ? arvalid : 1'd0;
            end
            default: arready = arvalid;
        endcase
end
 assign ns_rvalid=arready;
 assign awready=1'b1;
 assign wready=1'b1;
 assign tap_EN=1'b1;

 wire [(pDATA_WIDTH-1):0] ns_tap_Do, cs_tap_Do;

 assign ns_tap_Do=tap_Do;

dffr #(.WIDTH(32)) u_dffr_tap_do (.clk(axis_clk),.rst_n(axis_rst_n), .d(ns_tap_Do) , .q(cs_tap_Do));

always@(*)begin
    case(cs_state)
        IDLE:begin
                tap_WE={4{wvalid}};
        end 
        CAL:begin
            tap_WE=4'b0;
        end 
        default:begin
            tap_WE=4'b0
        end 
    endcase 
end 
always@(*)begin
    case(cs_state)
        IDLE:begin
                tap_Di=$signed(wdata);
        end 
        CAL:begin
            tap_Di=32'b0;
        end 
        default:begin
            tap_Di=32'b0
        end 
    endcase 
end 
always@(*)begin
    case(cs_state)
        IDLE:begin
                tap_A=      (awaddr == 12'h40) ? 11'h0 : 
                            (awaddr == 12'h44) ? 11'h4 :
                            (awaddr == 12'h48) ? 11'h8 :
                            (awaddr == 12'h4c) ? 11'hc :
                            (awaddr == 12'h50) ? 11'h10 :
                            (awaddr == 12'h54) ? 11'h14 :
                            (awaddr == 12'h58) ? 11'h18 :
                            (awaddr == 12'h5c) ? 11'h1c :
                            (awaddr == 12'h60) ? 11'h20 :
                            (awaddr == 12'h64) ? 11'h24 :
                            (awaddr == 12'h68) ? 11'h28 : 11'h0;
        end 
        CAL:begin
                if (cs_data_cnt >= 2'd0) begin
                    if (cs_data_out_cnt <= 10'd10) begin
                        tap_A = (cs_data_out - cs_data_acc) << 2'd2;
                    end
                    else if (cs_data_out > 10'd10) begin
                        tap_A = cs_tap_addr_cnt << 2'd2;
                    end
                end
        end 
        default:begin
            tap_Di=32'b0
        end 
    endcase 
end 
always@(*)begin
    case(cs_state)
        WAIT_OUT:begin
                sm_tdata=cs_res;
        end 
        default:begin
            sm_tdata=32'b0
        end 
    endcase 
end 
assign sm_tlast = (cs_data_out_cnt==cs_data_length-1)&&cs_sm_tready&&cs_sm_tvalid;
assign ss_tready =cs_ss_tready;
assign sm_tvalid =cs_sm_tvalid;
wire ns_ss_tready, cs_ss_tready;
wire ns_sm_tvalid, cs_sm_tvalid; 
dffr #(.WIDTH(1)) u_dffr_sm_tready (.clk(axis_clk),.rst_n(axis_rst_n),.d(ns_ss_tready),.q(cs_ss_tready));
dffr #(.WIDTH(1)) u_dffr_sm_tvalid (.clk(axis_clk),.rst_n(axis_rst_n),.d(ns_sm_tvalid),.q(cs_sm_tvalid));
always @(*) begin
        case(cs_state)
            WAIT_IN:begin
                ns_ss_tready = !ss_tvalid;
                ns_sm_tvalid =1'b0;
            end
            WAIT_OUT:begin
                ns_ss_tready=1'b0;
                ns_sm_tvalid=1'b1;
            end 
            default: begin 
                ns_ss_tready = 1'b0;
                ns_sm_tvalid = 1'b0;
            
            end 
        endcase
end
assign data_EN =1'b1;
wire [(pDATA_WIDTH-1):0] ns_data_Do, cs_data_Do;
wire [(pADDR_WIDTH-1):0] ns_data_A, cs_data_A;
dffr #(.WIDTH(pADDR_WIDTH)) u_dffr_data_A (.clk(axis_clk),.rst_n(axis_rst_n),.d(ns_data_A),.q(cs_data_A));
dffr #(.WIDTH(pDATA_WIDTH)) u_dffr_Do (.clk(axis_clk),.rst_n(axis_rst_n),.d(ns_data_Do),.q(cs_data_Do));

always (*)begin 
    case(cs_state)
        IDLE: begin 
            if(awaddr == 12'h40 ||cs_wait_data_cnt !=4'b0)begin 
                data_WE=4'hf;
                data_A =cs_wait_data_cnt<<2'h2;
                data_Di  =0;
            end 
        end 
        WAIT_IN:begin
            if(ss_tvalid && ss_tready)begin
                data_Di=$signed(ss_tdata);
                data_A=(cs_data_out_cnt%11)<<2'h2; 
                data_WE=4'hf;
        end 
        end
        CAL:begin
            data_WE=4'h0;
            if(cs_wait_data_cnt>=2'b0)begin
                if(data_out_cnt<=10'ha)begin
                    data_A=data_acc<<2'h2;
                    data_Di=0;
                end else if(cs_data_out_cnt >10'ha)begin
                    data_Di=0;
                    if(data_acc==4'h0)begin
                        data_A=(cs_data_out_cnt%11)<<2'h2;
                    end else begin 
                        data_A=cs_data_A+4'h4;
                        if(cs_data_A==11'h40)begin
                            ns_data_A=11'b0;
                        end
                    end 
                end
            end 
        end
    endcase
end 

always @(*)begin 
    case (cs_state)
            WAIT_IN: begin
                ns_res = 0;
            end
            CAL: begin
                ns_res = cs_data_Do * cs_tap_Do + cs_res;
            end
        endcase
end 

endmodule 

module dffr #(parameter WIDTH=1)(
  input clk,
  input rst,
  input [WIDTH-1:0] d,
  output reg [WIDTH-1:0] q
);

parameter RESET_VALUE =0;

always@(posedge clk or posedge rst)begin 
  if (rst)begin 
    q<= RESET_VALUE;
  end else begin 
    q<=d;
  end
end 



endmodule 

module dffs #(parameter WIDTH=1)(
  input clk,
  input rst,
  input [WIDTH-1:0] d,
  output reg [WIDTH-1:0] q
);

parameter RESET_VALUE =1;

always@(posedge clk or posedge rst)begin 
  if (rst)begin 
    q<= RESET_VALUE;
  end else begin 
    q<=d;
  end
end 

endmodule 






