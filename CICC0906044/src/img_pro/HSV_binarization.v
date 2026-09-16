`timescale 1ns/1ps

module HSV_binarization (
    input               clk,            // 时钟信号
    input               rst_n,          // 异步复位信号，低电平有效
    
    input       [1:0]   target_color,   // 目标颜色选择: 00=红, 01=蓝, 10=黄, 11=黑
    input       [7:0]   hsv_h,          // 输入的HSV色调分量
    input       [7:0]   hsv_s,          // 输入的HSV饱和度分量
    input       [7:0]   hsv_v,          // 输入的HSV亮度分量
    input               hsv_vs,         // 输入的垂直同步信号
    input               hsv_hs,         // 输入的的水平同步信号
    input               hsv_vld,        // 输入的有效视频信号
    
    output reg          binary_pixel,   // 输出的二值化像素值（0或1）
    output reg          vs_out,         // 输出的垂直同步信号
    output reg          hs_out,         // 输出的水平同步信号
    output reg          vld_out         // 输出的有效视频信号
);

// 颜色定义参数
localparam COLOR_RED   = 2'b00;
localparam COLOR_BLUE  = 2'b01;
localparam COLOR_YELLOW = 2'b10;
localparam COLOR_BLACK = 2'b11;

// 红色阈值 (注意红色在HSV色轮的两端)
localparam RED_H_MIN_LOW   = 8'd0;
localparam RED_H_MAX_LOW   = 8'd30;
localparam RED_S_MIN       = 8'd110;
localparam RED_S_MAX       = 8'd255;
localparam RED_V_MIN       = 8'd0;
localparam RED_V_MAX       = 8'd255;

// 蓝色阈值
localparam BLUE_H_MIN      = 8'd147;
localparam BLUE_H_MAX      = 8'd255;
localparam BLUE_S_MIN      = 8'd57;
localparam BLUE_S_MAX      = 8'd255;
localparam BLUE_V_MIN      = 8'd0;
localparam BLUE_V_MAX      = 8'd255;

// 黄色阈值
localparam YELLOW_H_MIN    = 8'd44;
localparam YELLOW_H_MAX    = 8'd255;
localparam YELLOW_S_MIN    = 8'd78;
localparam YELLOW_S_MAX    = 8'd255;
localparam YELLOW_V_MIN    = 8'd119;
localparam YELLOW_V_MAX    = 8'd255;

// 黑色阈值 (主要看V值)
localparam BLACK_H_MIN     = 8'd0;
localparam BLACK_H_MAX     = 8'd255;
localparam BLACK_S_MIN     = 8'd0;
localparam BLACK_S_MAX     = 8'd255;
localparam BLACK_V_MIN     = 8'd0;
localparam BLACK_V_MAX     = 8'd53;

// 中间信号
reg in_range;

// 同步信号流水线
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vs_out <= 1'b0;
        hs_out <= 1'b0;
        vld_out <= 1'b0;
    end
    else begin
        vs_out <= hsv_vs;
        hs_out <= hsv_hs;
        vld_out <= hsv_vld;
    end
end

// 颜色检测逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        binary_pixel <= 1'b0;
        in_range <= 1'b0;
    end
    else if (hsv_vld) begin
        case (target_color)
            COLOR_RED: begin
                in_range <= (hsv_h >= RED_H_MIN_LOW && hsv_h <= RED_H_MAX_LOW) &&
                            (hsv_s >= RED_S_MIN && hsv_s <= RED_S_MAX) &&
                            (hsv_v >= RED_V_MIN && hsv_v <= RED_V_MAX);
            end
            
            COLOR_BLUE: begin
                in_range <= (hsv_h >= BLUE_H_MIN && hsv_h <= BLUE_H_MAX) &&
                            (hsv_s >= BLUE_S_MIN && hsv_s <= BLUE_S_MAX) &&
                            (hsv_v >= BLUE_V_MIN && hsv_v <= BLUE_V_MAX);
            end
            
            COLOR_YELLOW: begin
                in_range <= (hsv_h >= YELLOW_H_MIN && hsv_h <= YELLOW_H_MAX) &&
                            (hsv_s >= YELLOW_S_MIN && hsv_s <= YELLOW_S_MAX) &&
                            (hsv_v >= YELLOW_V_MIN && hsv_v <= YELLOW_V_MAX);
            end
            
            COLOR_BLACK: begin
                in_range <= (hsv_v >= BLACK_V_MIN && hsv_v <= BLACK_V_MAX);
            end
            
            default: in_range <= 1'b0;
        endcase
        
        binary_pixel <= in_range;
    end
    else begin
        binary_pixel <= 1'b0;
    end
end

endmodule