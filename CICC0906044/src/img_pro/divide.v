`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: FPGA入门到精通公众号
// Engineer: 未可知
// 微信：1853097518
// 
// Create Date: 2023/11/19 16:55:46
// Design Name: 
// Module Name: divide
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//  除法器, 延时O_W+1个周期
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module divide#(
   parameter I_W = 32,
   parameter D_W = 9,
   parameter O_W = I_W - D_W
)(
    input wire Clk,
    input wire Rst,		   
	input wire valid_i,   //有效信号
    input wire [I_W-1:0] dividend,   //被除数
    input wire [D_W-1:0] divisor,   //除数 	 
    output wire valid_o,	  
    output wire [O_W-1:0] quotient,	//商
    output wire [D_W-1:0] remaind	//余数 
    );
    
    //变量声明
    localparam B_W = I_W + 1;
    genvar i;
    reg [D_W-1:0] divisor_buf [0:O_W+1];
    reg valid_buf [0:O_W+1];
    reg [B_W-1:0] dividend_buf [0:O_W+1];
    reg [O_W:0] quotient_buf [0:O_W+1];
    
    //赋初值
    always @(*) begin
        dividend_buf[0] = {1'b0, dividend};
        divisor_buf[0] = divisor;
        valid_buf[0] = valid_i;
        quotient_buf[0] = 0;
    end    

   
    //除法计算
    generate 
		for(i=1;i<=(O_W+1);i=i+1) begin: voluation
		
		always @(posedge Clk or posedge Rst) begin
			if(Rst) begin
				dividend_buf[i] <= 'b0;
				quotient_buf[i] <= 'b0;
			end else if(valid_buf[i-1]) begin 
				if(divisor_buf[i-1] == 'b0) begin //除数为0的情况
				   dividend_buf[i] <= 'b0;
				   quotient_buf[i] <= 'b0;
				end else if(dividend_buf[i-1][B_W-1:O_W] >= {1'b0, divisor_buf[i-1]}) begin //可能出现上一步的余数最高位也是1的情况
				   dividend_buf[i][B_W-1:O_W+1] <= dividend_buf[i-1][B_W-1:O_W] - divisor_buf[i-1];
				   dividend_buf[i][O_W:0] <= {dividend_buf[i-1][O_W-1:0], 1'b0};
				   quotient_buf[i] <= {quotient_buf[i-1][O_W:0],1'b1};
				end else begin
				   dividend_buf[i][B_W-1:O_W+1] <= dividend_buf[i-1][B_W-1:O_W];
				   dividend_buf[i][O_W:0] <= {dividend_buf[i-1][O_W-1:0], 1'b0};
				   quotient_buf[i] <= {quotient_buf[i-1][O_W:0],1'b0};
				end
			end else begin
				dividend_buf[i] <= 'b0;
				quotient_buf[i] <= 'b0;        
			end
		end

		always @(posedge Clk ) begin
			valid_buf[i] <= valid_buf[i-1];
			divisor_buf[i] <= divisor_buf[i-1];
		end    
		
		end
    endgenerate    
    
    assign valid_o = valid_buf[O_W+1];
    assign quotient = quotient_buf[O_W+1];
    assign remaind = dividend_buf[O_W+1][B_W-1:O_W+1];
    
endmodule
