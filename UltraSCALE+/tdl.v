`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:
// Design Name: 
// Module Name:
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module tdl( input en, input clk, input trigI, output [3:0]counter_value);
	tdl_on_slice seg0 ( 
		.en(en),
		.clk(clk),
		.and_gate0_I0(trigI),
		.counter_value(counter_value[3:0])
	);

endmodule


module tdl_on_slice( input en, input clk, input and_gate0_I0, output cascade_out, output [3:0]counter_value);
	wire [3:0] and_to_fd;

	(* s = "true" *) AND2 and_gate0 (
		.O(and_to_fd[0]),
		.I0(and_gate0_I0),
		.I1(en)
	);

	(* s = "true" *) AND2 and_gate1 (
		.O(and_to_fd[1]),
		.I0(and_to_fd[0]),
		.I1(en)
	);

	(* s = "true" *) AND2 and_gate2 (
		.O(and_to_fd[2]),
		.I0(and_to_fd[1]),
		.I1(en)
	);

	(* s = "true" *) AND2 and_gate3 (
		.O(and_to_fd[3]),
		.I0(and_to_fd[2]),
		.I1(en)
	);

	(* s = "true" *) FD d_ff0 (
		.C(clk),
		.D(and_to_fd[0]),
		.Q(counter_value[0])
	);

	(* s = "true" *) FD d_ff1 (
		.C(clk),
		.D(and_to_fd[1]),
		.Q(counter_value[1])
	);

	(* s = "true" *) FD d_ff2 (
		.C(clk),
		.D(and_to_fd[2]),
		.Q(counter_value[2])
	);

	(* s = "true" *) FD d_ff3 (
		.C(clk),
		.D(and_to_fd[3]),
		.Q(counter_value[3])
	);

	assign cascade_out = and_to_fd[3];
endmodule
