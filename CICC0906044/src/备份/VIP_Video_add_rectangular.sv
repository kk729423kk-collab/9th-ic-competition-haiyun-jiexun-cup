`timescale 1ns/1ns

/**
 * 四目标视频矩形框绘制模块
 * 功能：在视频图像上绘制四个目标的矩形框和边框
 * 特点：
 * - 支持四个目标的矩形框绘制
 * - 可配置不同颜色显示不同目标
 * - 支持640x480分辨率输入
 * - 可绘制大矩形框标记整个区域
 */
module VIP_Video_add_rectangular(
    // 全局时钟和复位
    input           clk,            // 系统时钟
    input           rst_n,          // 异步复位(低电平有效)
    
    // 图像数据输入接口
    input           per_frame_vsync,    // 场同步信号
    input           per_frame_href,     // 行同步信号
    input           per_frame_clken,    // 像素时钟使能
    input   [15:0]  in_img,             // 输入图像数据(RGB565格式)
    input   [2:0]   flag,               // 颜色选择标志
    
    // 目标区域位置输入
    input   [9:0]   left_pos,           // 整个区域左边界
    input   [9:0]   right_pos,          // 整个区域右边界
    input   [9:0]   up_pos,             // 整个区域上边界
    input   [9:0]   down_pos,           // 整个区域下边界
    
    // 四个目标的位置和形状信息
    input   [42:0]  target_out [3:0],   // 四个目标的信息(格式:[42:41]形状,[40]有效位,[39:30]底部,[29:20]右,[19:10]顶部,[9:0]左)
    
    // 图像数据输出接口
    output reg      post_frame_vsync,   // 输出场同步信号
    output reg      post_frame_href,    // 输出行同步信号
    output reg      post_frame_clken,   // 输出像素时钟使能
    output reg [15:0] out_img_Y         // 输出图像数据(RGB565格式)
);

// ==============================================
// 参数定义
// ==============================================
parameter IMG_HDISP = 11'd640;      // 水平分辨率640像素
parameter IMG_VDISP = 11'd480;      // 垂直分辨率480像素

// 颜色定义(RGB565格式)
localparam BLACK  = 16'b00000_000000_00000;  // 黑色
localparam WHITE  = 16'b11111_111111_11111;  // 白色
localparam RED    = 16'b11111_000000_00000;  // 红色
localparam BLUE   = 16'b00000_000000_11111;  // 蓝色
localparam GREEN  = 16'b00000_111111_00000;  // 绿色
localparam GRAY   = 16'b11000_110000_11000;  // 灰色
localparam YELLOW = 16'b11111_111111_00000;  // 黄色
localparam PURPLE = 16'b11111_000000_11111;  // 紫色
localparam CYAN   = 16'b00000_111111_11111;  // 青色

// ==============================================
// 像素坐标计数器
// ==============================================
reg [9:0] x_cnt;    // 当前像素水平坐标(0-639)
reg [9:0] y_cnt;    // 当前像素垂直坐标(0-479)

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        x_cnt <= 10'd0;
        y_cnt <= 10'd0;
    end
    else begin
        if(per_frame_vsync) begin       // 场同步信号复位计数器
            x_cnt <= 10'd0;
            y_cnt <= 10'd0;
        end
        else if(per_frame_clken) begin  // 像素时钟有效时计数
            if(x_cnt < IMG_HDISP - 1) begin
                x_cnt <= x_cnt + 1'b1;  // 行内像素计数
                y_cnt <= y_cnt;
            end
            else begin
                x_cnt <= 10'd0;         // 行结束，复位x计数
                y_cnt <= y_cnt + 1'b1;  // 增加行计数
            end
        end
    end
end

// ==============================================
// 绘制大矩形框标记整个区域
// ==============================================
reg border_flag;    // 大矩形框边界标志

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        border_flag <= 1'b0;
    end
    else begin
        // 判断上下边界(左右各15像素宽度)
        if((((x_cnt > left_pos) && (x_cnt < left_pos + 15)) || 
            ((x_cnt < right_pos) && (x_cnt > right_pos - 15))) && 
            ((y_cnt == up_pos) || (y_cnt == down_pos))) begin
            border_flag <= 1'b1;
        end
        // 判断左右边界(上下各15像素宽度)
        else if((((y_cnt > up_pos) && (y_cnt < up_pos + 15)) || 
                ((y_cnt < down_pos) && (y_cnt > down_pos - 15))) && 
                ((x_cnt == left_pos) || (x_cnt == right_pos))) begin
            border_flag <= 1'b1;
        end
        else begin
            border_flag <= 1'b0;
        end
    end
end

// ==============================================
// 绘制四个目标的矩形框
// ==============================================
wire [3:0] char_flag;               // 各目标的有效标志
wire [9:0] char_left   [3:0];       // 各目标的左边界
wire [9:0] char_right  [3:0];       // 各目标的右边界
wire [9:0] char_up     [3:0];       // 各目标的上边界
wire [9:0] char_down   [3:0];       // 各目标的下边界

// 生成四个目标的位置信息
generate
genvar i;
    for(i=0; i<4; i = i+1) begin : CHAR_POS
        assign char_flag[i]    = target_out[i][40];    // 目标有效标志
        assign char_left[i]    = target_out[i][ 9: 0];  // 左边界
        assign char_right[i]    = target_out[i][29:20]; // 右边界
        assign char_up[i]      = target_out[i][19:10];  // 上边界
        assign char_down[i]    = target_out[i][39:30];  // 下边界
    end
endgenerate

// 四个目标的边框绘制标志
integer j;
reg [3:0] char_border_flag;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        char_border_flag <= 4'd0;
    end
    else begin
        for(j=0; j<4; j = j+1) begin
            // 判断上下边界
            if((x_cnt > char_left[j]) && (x_cnt < char_right[j]) && 
               ((y_cnt == char_up[j]) || (y_cnt == char_down[j]))) begin
                char_border_flag[j] <= char_flag[j];
            end
            // 判断左右边界
            else if((y_cnt > char_up[j]) && (y_cnt < char_down[j]) && 
                   ((x_cnt == char_left[j]) || (x_cnt == char_right[j]))) begin
                char_border_flag[j] <= char_flag[j];
            end
            else begin
                char_border_flag[j] <= 1'b0;
            end
        end
    end
end

// 合并四个目标的边框标志
wire char_border_flag_final = (char_border_flag != 4'd0);

// ==============================================
// 输出图像处理
// ==============================================
reg         per_frame_vsync_r;
reg         per_frame_href_r;
reg         per_frame_clken_r;
reg [15:0]  in_img_Y_r;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        per_frame_vsync_r   <= 0;
        per_frame_href_r    <= 0;
        per_frame_clken_r  <= 0;
        in_img_Y_r         <= 0;
        
        post_frame_vsync    <= 0;
        post_frame_href     <= 0;
        post_frame_clken    <= 0;
        out_img_Y          <= 0;
    end
    else begin
        // 同步输入信号
        per_frame_vsync_r   <= per_frame_vsync;
        per_frame_href_r    <= per_frame_href;
        per_frame_clken_r   <= per_frame_clken;
        in_img_Y_r          <= in_img;
        
        // 输出同步信号
        post_frame_vsync    <= per_frame_vsync_r;
        post_frame_href     <= per_frame_href_r;
        post_frame_clken    <= per_frame_clken_r;
        
        // 根据flag选择不同颜色绘制目标边框
        case(flag)
            3'd0: out_img_Y <= border_flag ? GREEN : (char_border_flag_final ? RED    : in_img_Y_r);
            3'd1: out_img_Y <= border_flag ? GREEN : (char_border_flag_final ? YELLOW : in_img_Y_r);
            3'd2: out_img_Y <= border_flag ? GREEN : (char_border_flag_final ? BLUE   : in_img_Y_r);
            3'd3: out_img_Y <= border_flag ? GREEN : (char_border_flag_final ? BLACK  : in_img_Y_r);
            3'd4: out_img_Y <= border_flag ? GREEN : (char_border_flag_final ? PURPLE : in_img_Y_r);
            3'd5: out_img_Y <= border_flag ? GREEN : (char_border_flag_final ? CYAN   : in_img_Y_r);
            default: out_img_Y <= in_img_Y_r;
        endcase
    end
end

endmodule