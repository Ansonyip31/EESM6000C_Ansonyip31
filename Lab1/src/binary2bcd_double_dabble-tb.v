`include "binary2bcd_double_dabble.v"
//~ `New testbench
`timescale  1ns / 1ps

module tb_top_modeule;

// top_modeule Parameters
parameter PERIOD  = 10;
parameter LARGE_NUMBER = 255;
integer i, j, error;


// top_modeule Inputs
reg [7:0] in_binary = 0;
reg clk;
reg rst_n;

// top_modeule Outputs
wire [7:0] packed_bcd;
wire [15:0] unpacked_bcd;

// there you can read data from the solution file,and store in the register.
reg [7:0] solution [0:99];
initial begin
  $readmemb("/home/ubuntu/Downloads/solution.dat",solution);
end


binary2bcd_double_dabble  u_top_modeule (
    .in_binary(in_binary[7:0]),
    .packed_bcd(packed_bcd[7:0]),
    .unpacked_bcd(unpacked_bcd[15:0])
);


//generate clk
always #(PERIOD/2) clk = ~clk;

initial begin
    clk = 1;
    rst_n = 1;

    #(PERIOD) rst_n = 0; // system reset
    #(PERIOD) rst_n = 1;

end

//dump the waveform of the simulation
initial begin
    $dumpfile("binary2bcd_double_dabble-tb.vcd");
    $dumpvars;
end

// testing input 
initial
begin
    wait(rst_n == 0);
    wait(rst_n == 1);
    in_binary = 8'b0000_0000;
    for (i = 0; i < LARGE_NUMBER; i = i + 1) begin
        @ (negedge clk) in_binary = in_binary + 1;
    end
end

//check result
initial begin
    error = 0; // error count
    wait(rst_n == 0);
    wait(rst_n == 1);
    //auto check
    for (j = 0; j <= 99; j = j + 1) begin //compare the solution with the simulation result.
        @(negedge clk);
        if (packed_bcd != solution[j][7:0]) begin
            error = error + 1;
            $display("pattern number No.%d is wrong at %t", j, $time);
            $display("your answer is %b, but the correct answer is %b", packed_bcd, solution[j]);
        end
    end

    if (error == 0) begin
        $display("Your answer is correct!");
    end else begin
        $display("Your answer is wrong!");
    end

    #(PERIOD)$finish;

end

endmodule
