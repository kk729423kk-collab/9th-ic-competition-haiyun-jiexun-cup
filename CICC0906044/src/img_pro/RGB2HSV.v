`timescale 1ns / 1ps
module RGB2HSV(
   input wire Clk,
   input wire Rst,
   
   input 	  vs,
   input 	  hs,
   input wire valid_i,
   input wire [23:0] rgb_data_i,
   
   output wire hsv_vs,
   output wire hsv_hs,
   output wire valid_o,
   output wire [23:0] hsv_data_o
);
//////////////////////////////
	reg [9:0]  	x_cnt;
	reg [9:0]   y_cnt;
//////////////////////////////对输入的像素进行 行/场 方向计数，得到其纵横坐标。
	always@(posedge Clk or posedge Rst)
	begin
		if(Rst)
			begin
				x_cnt <= 10'd0;
				y_cnt <= 10'd0;
			end
		else
			if(vs)begin
				x_cnt <= 10'd0;
				y_cnt <= 10'd0;
			end
			else if(valid_i) begin
				if(x_cnt < 639) begin
					x_cnt <= x_cnt + 1'b1;
					y_cnt <= y_cnt;
				end
				else begin
					x_cnt <= 10'd0;
					y_cnt <= y_cnt + 1'b1;
				end
			end
	end
//////////////////////////////有效范围
	wire valid_area,valid_area1;
	assign valid_area1 = (x_cnt >= 120 && x_cnt <= 520 && y_cnt >= 110 && y_cnt <= 370);
	
	assign valid_area = valid_area1;  
//////////////////////////////变量声明
    wire [7:0] R, G, B;
    reg valid_d1;
    reg [7:0] var_Min, var_Max;
    reg [8:0] var_Ext;
    reg [1:0] var_Max_id;
    reg [7:0] R_d1, G_d1, B_d1;

    reg valid_d2;
    wire [7:0] del_Max_w;
    reg [15:0] del_Max_m255;
    reg [10:0] del_Max_m6;
    reg [7:0] var_Max_d1;
    wire [10:0] H_w;
    reg [18:0] H_del;

    reg [8*9-1:0] var_Max_d1_shift_r;
    wire s_div_valid_w;
    wire [7:0] S;
    wire h_div_valid_w;
    wire [7:0] H;
    wire [7:0] V;
//////////////////////////////计算RGB中的最大值和最小值
    assign {R, G, B} = rgb_data_i;
    always @(posedge Clk or posedge Rst) begin
        if(Rst) begin
            valid_d1 <= 0;
            {var_Min, var_Max} <= 0;
            var_Ext <= 0;
            var_Max_id <= 0;
            {R_d1, G_d1, B_d1} <= 0;           
        end else begin
            valid_d1 <= valid_i;
            if(valid_i) begin
                var_Min <= (R > G) ? ((G > B) ? B : G) : (R > B) ? B : R;
                if(R > G) begin
                    if(R > B) begin
                        var_Max <= R;
                        var_Max_id <= 0;
                        var_Ext <= (G > B) ? G - B : 0;
                    end else begin
                        var_Max <= B;
                        var_Max_id <= 2;
                        var_Ext <= R - {1'b0, G};
                    end
                end else if(G > B) begin
                    var_Max <= G;
                    var_Max_id <= 1;
                    var_Ext <= B - {1'b0, R};
                end else begin
                    var_Max <= B;
                    var_Max_id <= 2;
                    var_Ext <= R - {1'b0, G};
                end
            end
           {R_d1, G_d1, B_d1} <= {R, G, B};
        end
    end
//////////////////////////////
    assign del_Max_w = var_Max - var_Min;
    //有符号数运算
    assign H_w = (var_Max_id == 0) ? {2'b0, var_Ext} : (var_Max_id == 1) ? ({del_Max_w, 1'b0} + {{2{var_Ext[8]}}, var_Ext}) : ({del_Max_w, 2'b0} + {{2{var_Ext[8]}}, var_Ext});
    always @(posedge Clk or posedge Rst) begin
        if(Rst) begin
            valid_d2 <= 0;
            del_Max_m255 <= 0;
            del_Max_m6 <= 0;
            H_del <= 0;
            var_Max_d1 <= 0;
        end else begin
            valid_d2 <= valid_d1;
            if(valid_d1) begin
                del_Max_m255 <= {del_Max_w, 8'b0} - del_Max_w;
                del_Max_m6 <= {del_Max_w, 2'b0} + {del_Max_w, 1'b0};
                H_del <= H_w[10]||(del_Max_w == 0) ? 0 : {H_w, 8'b0} - H_w;
            end
            var_Max_d1 <= var_Max;
        end
    end

//////////////////////////////VarMax做延时处理
    always@(posedge Clk) begin
        var_Max_d1_shift_r <= {var_Max_d1_shift_r, var_Max_d1};
    end
//////////////////////////////除法计算
    //计算S，延时16-8+1=9
    divide#(
      .I_W      ( 16 ),
      .D_W      ( 8 )
    )u_divide0(
      .Clk      ( Clk      ),
      .Rst    ( Rst    ),
      .valid_i  ( valid_d2  ),
      .dividend ( del_Max_m255 ),
      .divisor  ( var_Max_d1  ),
      .valid_o  ( s_div_valid_w  ),
      .quotient ( S ),
      .remaind  (   )
    );

    //计算H，延时19-11+1=9
    divide#(
      .I_W      ( 19 ),
      .D_W      ( 11 )
    )u_divide1(
      .Clk      ( Clk      ),
      .Rst    ( Rst    ),
      .valid_i  ( valid_d2  ),
      .dividend ( H_del ),
      .divisor  ( del_Max_m6  ),
      .valid_o  ( h_div_valid_w  ),
      .quotient ( H ),
      .remaind  (   )
    ); 
//////////////////////////////
    //计算V
    assign V = var_Max_d1_shift_r[8*9-1:8*8];

    assign valid_o = s_div_valid_w;
    assign hsv_data_o = valid_area?{H, S, V}:24'h253250;
//////////////////////////////同步信号
	reg [10:0]vs_delay;
	reg	[10:0]hs_delay;
//////////////////////////////	
	always@(posedge Clk or posedge Rst)begin
		if(Rst)begin
			vs_delay<=0;
			hs_delay<=0;
		end
		else begin
			vs_delay <= { vs_delay[9:0],vs};
			hs_delay <= { hs_delay[9:0],hs};
		end
	end
//////////////////////////////
	assign hsv_vs=vs_delay[10];
	assign hsv_hs=hs_delay[10];
////////////////////////////// 
endmodule
