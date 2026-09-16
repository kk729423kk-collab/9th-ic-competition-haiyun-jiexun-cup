`timescale 1ns / 1ns
module sqrt_ctrl(
	input 				Clk		,
	input				Rst_n	,
	input 				update	,
	input 		[16:0]	IN_DATA	,
	output reg 			finish	,
	output reg	[15:0]	OUT_DATA
);
///////////////////////////////////////
	reg [2:0]finish_r;
	reg [16:0]	radical;
	wire [8:0] q;
///////////////////////////////////////
	always@(posedge Clk or negedge Rst_n)begin
		if(!Rst_n)
			radical <= 'b0;
		else	
			radical <= IN_DATA;
	end
///////////////////////////////////////
	always@(posedge Clk or negedge Rst_n)begin
		if(!Rst_n)begin
			finish_r <= 'b0;
			finish <= 'b0;
		end
		else begin	
			finish_r <= {finish_r[1:0],update};
			finish <= finish_r[2];
		end
	end
///////////////////////////////////////
	always@(posedge Clk or negedge Rst_n)begin
		if(!Rst_n)
			OUT_DATA <= 'b0;
		else if(finish_r[1])
			OUT_DATA <= q;
		else
			OUT_DATA <= OUT_DATA;
	end
///////////////////////////////////////
	sqrt sqrt(
		.radical	(radical),
		.q			(q),
		.remainder  ()
	);
///////////////////////////////////////
endmodule
