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
module iodelay_fsm(
	input	resetn,
	input	clk,
	input	sampling_trig,
	input	CALIB_DIPSW,
	input	lbus_clk96,
	output	gate_input_delayed,
	output	iodelay2Out
);
	 
	wire	sampling_clk;
	wire	tracer_busy;
	reg		sampling_trig_previous;
	reg		IODELAY2_gate_path_CE;
	reg		IODELAY2_gate_path_CAL;
	reg		IODELAY2_gate_path_RST;
  
  
	always @(posedge clk or negedge resetn)
	begin
		if ( resetn == 1'b0 )
		begin
			sampling_trig_previous <= 0;
			IODELAY2_gate_path_CE <= 0;
		end
		else
		begin	
			sampling_trig_previous <= sampling_trig;
			if ((sampling_trig == 1) && (sampling_trig_previous == 0) && (CALIB_DIPSW == 1))
				IODELAY2_gate_path_CE <= 1;
			else
				IODELAY2_gate_path_CE <= 0;
		end
	end

	assign iodelay2Out = lbus_clk96;

	parameter s_iodelay_START         = 2'b00;
	parameter s_iodelay_DELAY         = 2'b01;
	parameter s_iodelay_RESET         = 2'b10;
	parameter s_iodelay_IDLE          = 2'b11;

	reg [1:0] r_FSM_iodelay = s_iodelay_IDLE;
  
 
	always @(posedge clk)
	begin  
		case (r_FSM_iodelay)
			s_iodelay_START :
			begin
				if ( resetn == 1'b0 )
				begin
					IODELAY2_gate_path_CAL <= 0;
					r_FSM_iodelay <= s_iodelay_START;
				end
				else
				begin				
					IODELAY2_gate_path_CAL <= 1;
					r_FSM_iodelay <= s_iodelay_DELAY;	
				end
			end

			s_iodelay_DELAY :
			begin
				IODELAY2_gate_path_CAL <= 0;
				r_FSM_iodelay <= s_iodelay_RESET;
			end

			s_iodelay_RESET :
			begin
				IODELAY2_gate_path_RST <= 1;
				r_FSM_iodelay <= s_iodelay_IDLE;
			end

			s_iodelay_IDLE :
			begin
				IODELAY2_gate_path_RST <= 0;
				if (resetn == 1'b0)
					r_FSM_iodelay <= s_iodelay_START;
				else
					r_FSM_iodelay <= s_iodelay_IDLE;
			end

		default :
			r_FSM_iodelay <= s_iodelay_START;

		endcase
	end
	 
	(* IODELAY_GROUP = "<iodelay_group_gate_path>" *)
	
	IDELAYCTRL #(
		.SIM_DEVICE("ULTRASCALE")
	)IDELAYCTRL_gate_path (
		.RDY(),
		.REFCLK(lbus_clk96),
		.RST(IODELAY2_gate_path_RST)
	);  

	IDELAYE3 #(
		.CASCADE("NONE"),
		.DELAY_FORMAT("COUNT"),
		.DELAY_SRC("DATAIN"),
		.DELAY_TYPE("VARIABLE"),
		.DELAY_VALUE(0),
		.IS_CLK_INVERTED(1'b0),
		.IS_RST_INVERTED(1'b0),
		.REFCLK_FREQUENCY(300.0),
		.UPDATE_MODE("ASYNC"),
		.SIM_DEVICE("ULTRASCALE_PLUS")
	)
	IDELAYE3_gate_path (
		.CASC_OUT(),
		.CNTVALUEOUT(),
		.DATAOUT(gate_input_delayed),
		.CASC_IN(),
		.CASC_RETURN(),
		.CE(IODELAY2_gate_path_CE),
		.CLK(clk),
		.CNTVALUEIN(),
		.DATAIN(lbus_clk96),
		.EN_VTC(1'b0),
		.IDATAIN(),
		.INC(1'b1),
		.LOAD(),
		.RST(IODELAY2_gate_path_RST)
	);

endmodule
