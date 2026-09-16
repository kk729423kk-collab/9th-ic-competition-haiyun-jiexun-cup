module HSV_binarization(
    input 				Clk,            // 时钟信号
    input 				Rst_n,          // 异步复位信号，低电平有效
			
    input 		[7:0] 	hsv_h,          // 输入的HSV色调分量
    input 		[7:0] 	hsv_s,          // 输入的HSV饱和度分量
    input 		[7:0] 	hsv_v,          // 输入的HSV亮度分量
    input 				hsv_vs,         // 输入的HSV垂直同步信号
    input 				hsv_hs,         // 输入的HSV水平同步信号
    input 				hsv_vld,         // 输入的HSV有效视频信号
	
    output reg  		binary_pixel,  	//输出的二值化像素值（0或1）
    output reg 			vs_out,         // 输出的垂直同步信号
    output reg 			hs_out,         // 输出的水平同步信号
    output reg 			vld_out          // 输出的有效视频信号
);
///////////////////////////////////////
parameter[7:0]	h_threshold_min=150,
                h_threshold_max=175,
                s_threshold_min=100,
                s_threshold_max=255,
                v_threshold_min=0,
                v_threshold_max=255;

///////////////////////////////////////二值化处理
	always @(posedge Clk or negedge Rst_n) begin
		if (!Rst_n) begin
			binary_pixel <= 'b0;
		end else if (hsv_vld && 1) begin
			if (hsv_h >= h_threshold_min && hsv_h <= h_threshold_max &&
				hsv_s >= s_threshold_min && hsv_s <= s_threshold_max &&
				hsv_v >= v_threshold_min && hsv_v <= v_threshold_max) begin
				binary_pixel <= 'b1;
			end else begin
				binary_pixel <= 'b0;
			end
		end else begin
			binary_pixel <= 'b0;
		end
	end
///////////////////////////////////////
	always @(posedge Clk or negedge Rst_n)begin
		if (!Rst_n) begin
			vs_out <= 'b0;
			hs_out <= 'b0;
			vld_out <= 'b0;
		end
		else begin
			vs_out <= hsv_vs;
			hs_out <= hsv_hs;
			vld_out <= hsv_vld;
		end
	end
///////////////////////////////////////
endmodule