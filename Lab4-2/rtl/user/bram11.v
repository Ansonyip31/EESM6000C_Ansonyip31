module bram11
(
    CLK,
    WE,
    EN,
    Di,
    Do,
    A
);
    parameter ADDR_WIDTH = 12;
    parameter SIZE = 11;
    parameter BIT_WIDTH = 32;

    input   wire            CLK;
    input   wire     [3:0]  WE;
    input   wire            EN;
    input   wire    [BIT_WIDTH-1:0]  Di;
    output  wire    [BIT_WIDTH-1:0]  Do;
    input   wire    [ADDR_WIDTH-1:0]  A;

    reg [BIT_WIDTH-1:0] RAM[ADDR_WIDTH-1:0];
    reg [ADDR_WIDTH-1:0] r_A;



    always @(posedge CLK) begin
    r_A <= A;
    end

    assign Do = {32{EN}} & RAM[r_A>>2];    // read

    wire [11:0] WA = A;
    always @(posedge CLK) begin
        if(EN) begin

        if(WE[0])
            RAM[WA>>2][7:0] <=  Di[7:0];
        if(WE[1])
            RAM[WA>>2][15:8] <=  Di[15:8];
        if(WE[2])
            RAM[WA>>2][23:16] <=  Di[23:16];
        if(WE[3])
            RAM[WA>>2][31:24] <=  Di[31:24];
        end
    end
endmodule
