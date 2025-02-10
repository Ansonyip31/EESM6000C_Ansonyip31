module binary2bcd_double_dabble (
    input wire [7:0]in_binary,
    output wire [7:0]packed_bcd,
    output wire [15:0]unpacked_bcd
);
    reg [15:0]scratch_pad[0:8];
    integer i;
    always @( *) begin
        scratch_pad[0][15:0] = {8'b0000_0000, in_binary};
        for (i = 1; i < 8 ; i = i + 1) begin
            scratch_pad[i][15:0]= scratch_pad[i-1][15:0] << 1;
            if (scratch_pad[i][11:8] > 4'b0100) begin
                scratch_pad[i][11:8] = scratch_pad[i][11:8] + 4'b0011;
            end else begin
                scratch_pad[i][11:8] = scratch_pad[i][11:8];
            end   
        end
        scratch_pad[8][15:0] = scratch_pad[7][15:0] << 1;
    end
    assign packed_bcd = scratch_pad[8][15:8];
    assign unpacked_bcd = {4'b0000, scratch_pad[8][15:12], 4'b0000, scratch_pad[8][11:8]};
endmodule