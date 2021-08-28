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


module viti(
	input 			   resetn,
	input 			   clk,
	input 			   lbus_clk96,
	input 			   sampling_trig,
	input 			   uart_tx_Active,
	input 			   uart_tx_Done,
	output reg		   uart_tx_DV,
	output reg [7:0]   uart_tx_Byte,
	output reg		   busy
);

	reg		[2:0] ones_in_a_reading = 3'b100;
	reg		[7:0] readings_with_unmatching_ones;
	reg		[7:0] sampling_index;
	reg		[7:0] buffer_index;
	reg			  buffer_rden = 1'b0;
	reg			  buffer_wren = 1'b0;
	reg			  ro_enable = 1'b0;
	reg			  calib_sw = 1'b1;
	wire	[3:0] ram_out;
	wire	[3:0] counter_out;
	wire		  iodelay2Out;

	parameter s_cap_IDLE        = 2'b00;
	parameter s_cap_FILLING     = 2'b01;
	parameter s_cap_FULL        = 2'b10;

	reg 	[1:0] r_FSM_cap = s_cap_IDLE;

	parameter s_m_IDLE           = 3'b000;
	parameter s_m_SAMPLING       = 3'b001;
	parameter s_m_BUFFER_FULL    = 3'b010;
	parameter s_m_DELAY_CYCLE    = 3'b011;
	parameter s_m_TRANSFER       = 3'b100;
	parameter s_m_WAIT_FSM_TX    = 3'b101;
	parameter s_m_CLEANUP        = 3'b110;

	reg 	[2:0] r_FSM_main = s_m_IDLE;

	parameter s_tx_IDLE          = 2'b00;
	parameter s_tx_PREP          = 2'b01;
	parameter s_tx_WAITING       = 2'b10;
	parameter s_tx_DONE          = 2'b11;

	reg 	[1:0] r_FSM_tx = s_tx_IDLE;
	
	BUFG sampling_clkdrv (.I(iodelay2Out), .O(sampling_clk));
  
	iodelay_fsm iodelay_fsm(
		.resetn(resetn),
		.clk(clk),
		.sampling_trig(sampling_trig),
		.CALIB_DIPSW(calib_sw),
		.lbus_clk96(lbus_clk96),
		.gate_input_delayed(and_gate_in),
		.iodelay2Out(iodelay2Out)
	);

	BRAM_SDP_MACRO #(
		.BRAM_SIZE("9Kb"),
		.DEVICE("SPARTAN6"),
		.WRITE_WIDTH(4),
		.READ_WIDTH(4),
		.DO_REG(0),
		.INIT_FILE ("NONE"),
		.SIM_COLLISION_CHECK ("ALL")
		) buffer (
		.RST(~resetn),
		.DI(counter_out),
		.WRADDR({3'b000, sampling_index}),
		.WRCLK(sampling_clk),
		.WREN(buffer_wren),
		.WE(1'b1),
		.DO(ram_out),
		.RDADDR({3'b000, buffer_index}),
		.RDCLK(clk),
		.RDEN(buffer_rden)
	);

	tdl tdl (
		.en(ro_enable),
		.clk(sampling_clk),
		.trigI(and_gate_in),
		.counter_value(counter_out)
	);
 
	always @(posedge sampling_clk)
	begin
		case (r_FSM_cap)
			s_cap_IDLE :
			begin
				sampling_index <= 9'b0;
				if ((r_FSM_main == s_m_SAMPLING) & (resetn == 1'b1))
				begin
					ro_enable <= 1'b1;
					buffer_wren <= 1'b1;
					r_FSM_cap <= s_cap_FILLING;
				end
			end

			s_cap_FILLING :
			begin
				sampling_index <= sampling_index + 1'b1;
				if (sampling_index == 255)
					r_FSM_cap <= s_cap_FULL;
			end

			s_cap_FULL :
			begin
				ro_enable <= 1'b0;
				buffer_wren <= 1'b0;
				if (r_FSM_main == s_m_BUFFER_FULL)
					r_FSM_cap <= s_cap_IDLE;
			end

		default :
			r_FSM_cap <= s_cap_IDLE;
		endcase
	end

	always @(posedge clk)
	begin  
		case (r_FSM_main)
			s_m_IDLE :
			begin
				if ((sampling_trig == 1'b1) & (resetn == 1'b1))
				begin
					busy <= 1'b1;
					r_FSM_main <= s_m_SAMPLING;
				end
				else
				begin
					busy <= 1'b0;
					buffer_rden <= 0;
				end
			end

			s_m_SAMPLING :
			begin
				if (r_FSM_cap == s_cap_FULL)
				begin
					buffer_rden <= 1; 
					buffer_index <= 9'b0;
					r_FSM_main <= s_m_BUFFER_FULL;
				end
			end

			s_m_BUFFER_FULL :
			begin
				readings_with_unmatching_ones <= 0;
				r_FSM_main <= s_m_DELAY_CYCLE;
			end
			 
			s_m_DELAY_CYCLE :
			begin
				uart_tx_Byte <= {4'b0000, ram_out[3:0]};
				if ((buffer_index > 144) && (buffer_index < 177))
				begin
					if(ram_out[3] + ram_out[2] + ram_out[1] + ram_out[0] != ones_in_a_reading)
						readings_with_unmatching_ones <= readings_with_unmatching_ones + 1;
				end
				r_FSM_main <= s_m_TRANSFER;
			end

			s_m_TRANSFER :
			begin
				if (r_FSM_tx == s_tx_IDLE)
					r_FSM_main <= s_m_WAIT_FSM_TX;
			end

			s_m_WAIT_FSM_TX :
			begin
				if (r_FSM_tx == s_tx_DONE)
				begin 
					if (buffer_index == 255)
					begin
						if (readings_with_unmatching_ones == 32)
							ones_in_a_reading <= ram_out[3] + ram_out[2] + ram_out[1] + ram_out[0];
						else if ((readings_with_unmatching_ones < 32) && (readings_with_unmatching_ones > 0))
							calib_sw <= 1'b0;
						r_FSM_main <= s_m_CLEANUP;
					end
					else
					begin
						buffer_index <= buffer_index + 1'b1;
						r_FSM_main <= s_m_DELAY_CYCLE;
					end
				end
			end

			s_m_CLEANUP :
			begin
				busy <= 1'b0;
				buffer_rden <= 0;
				r_FSM_main <= s_m_IDLE;
			end

		default :
			r_FSM_main <= s_m_IDLE;

		endcase
	end

	always @(posedge clk)
	begin  
		case (r_FSM_tx)
			s_tx_IDLE :
			begin
				if (r_FSM_main == s_m_WAIT_FSM_TX)
					r_FSM_tx <= s_tx_PREP;
			end

			s_tx_PREP :
			begin
				uart_tx_DV <= 1'b1;
				r_FSM_tx <= s_tx_WAITING;
			end

			s_tx_WAITING :
			begin
				uart_tx_DV <= 1'b0;
				if (uart_tx_Done == 1'b1)
					r_FSM_tx <= s_tx_DONE;
			end

			s_tx_DONE :
			begin
				if ((r_FSM_main == s_m_CLEANUP) | (r_FSM_main == s_m_TRANSFER))
					r_FSM_tx <= s_tx_IDLE;
			end

		default :
			r_FSM_tx <= s_tx_IDLE;

		endcase
	end
	 
endmodule