`timescale 1ns/1ns

module VIP_Video_add_rectangular(
    input           clk,                 // 像素时钟
    input           rst_n,               // 复位(低有效)
    input           per_frame_vsync,     // 场同步
    input           per_frame_href,      // 行同步
    input           per_frame_clken,     // 像素使能
    input   [15:0]  in_img,              // 输入图像(RGB565)
    input   [42:0]  target_out [3:0],    // 目标信息数组
    output reg      post_frame_vsync,    // 输出场同步
    output reg      post_frame_href,     // 输出行同步
    output reg      post_frame_clken,    // 输出像素使能
    output reg [15:0] out_img_Y          // 输出图像
);

// 分辨率参数
parameter IMG_HDISP = 11'd640;         // 水平分辨率
parameter IMG_VDISP = 11'd480;         // 垂直分辨率
parameter CROSS_SIZE = 10'd5;           // 十字线宽度

// 颜色定义
localparam WHITE  = 16'b11111_111111_11111;  // 十字线颜色
localparam YELLOW = 16'b11111_111111_00000;  // 目标框颜色
localparam GREEN  = 16'b00000_111111_00000;  // 固定边框颜色（绿色）

// 像素坐标计数器
reg [9:0] x_cnt, y_cnt;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        x_cnt <= 0;
        y_cnt <= 0;
    end else begin
        if(per_frame_vsync) begin
            x_cnt <= 0;
            y_cnt <= 0;
        end else if(per_frame_clken) begin
            x_cnt <= (x_cnt < IMG_HDISP-1) ? x_cnt + 1 : 0;
            y_cnt <= (x_cnt < IMG_HDISP-1) ? y_cnt : y_cnt + 1;
        end
    end
end

// 中心十字线
wire center_x = (x_cnt >= 320 - CROSS_SIZE) && (x_cnt <= 320 + CROSS_SIZE);
wire center_y = (y_cnt >= 240 - CROSS_SIZE) && (y_cnt <= 240 + CROSS_SIZE);
wire cross_flag = (x_cnt == 320) || (y_cnt == 240) || (center_x && center_y);

// 目标框检测
wire [3:0] char_flag;
wire [9:0] char_left[3:0], char_right[3:0], char_up[3:0], char_down[3:0];

generate
genvar i;
for(i=0; i<4; i=i+1) begin : TARGET_GEN
    assign char_flag[i] = target_out[i][40];
    assign char_left[i] = target_out[i][9:0];
    assign char_right[i] = target_out[i][29:20];
    assign char_up[i] = target_out[i][19:10];
    assign char_down[i] = target_out[i][39:30];
end
endgenerate

// 目标边框标志
reg [3:0] char_border_flag;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        char_border_flag <= 0;
    end else begin
        for(int j=0; j<4; j=j+1) begin
            char_border_flag[j] <= 
                (((x_cnt > char_left[j]) && (x_cnt < char_right[j]) && 
                  ((y_cnt == char_up[j]) || (y_cnt == char_down[j]))) ||
                 ((y_cnt > char_up[j]) && (y_cnt < char_down[j]) && 
                  ((x_cnt == char_left[j]) || (x_cnt == char_right[j])))) && 
                char_flag[j];
        end
    end
end

wire target_border = |char_border_flag;  // 任意目标边框有效

// 修改后的固定边框范围（120<=x<=520, 110<=y<=370）
wire fixed_border = 
    ((x_cnt == 120 || x_cnt == 520) && (y_cnt >= 110 && y_cnt <= 370)) ||  // 左右边框
    ((y_cnt == 110 || y_cnt == 370) && (x_cnt >= 120 && x_cnt <= 520));    // 上下边框

// 输出处理（优先级：十字线 > 固定边框 > 目标框 > 原图）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {post_frame_vsync, post_frame_href, post_frame_clken} <= 0;
        out_img_Y <= 0;
    end else begin
        post_frame_vsync <= per_frame_vsync;
        post_frame_href <= per_frame_href;
        post_frame_clken <= per_frame_clken;
        
        out_img_Y <= cross_flag ? WHITE : 
                    (fixed_border ? GREEN : 
                    (target_border ? YELLOW : in_img));
    end
end

endmodule