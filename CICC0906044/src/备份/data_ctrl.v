`timescale 1ns/1ns

/**
 * 目标坐标转换模块（整数输出）
 * 功能：根据输入的目标形状选择对应的目标，输出其实际坐标
 * 特点：
 * - 内部使用Q16定点数计算
 * - 最终输出为整数坐标值（单位：mm）
 * - 修复了Y偏置未正确添加的问题
 * - 输入四个目标的形状和位置信息
 * - 根据目标形状选择输出对应目标的坐标
 * - 保持Y轴方向与图像一致（向下为正）
 * - 缩放系数0.48（Q16格式）
 */
module data_ctrl(
    // 系统接口
    input               clk,            // 系统时钟
    input               rst_n,          // 异步复位(低电平有效)
    
    // 目标输入接口
    input       [42:0]  target_out [3:0],  // 4个目标信息
    input       [1:0]   target_shape,    // 要输出的目标形状编码
    
    // 实际坐标输出(整数)
    output wire [15:0]  real_x,         // X坐标(整数mm)
    output wire [15:0]  real_y,         // Y坐标(整数mm)
    output reg          valid           // 坐标有效标志
);

// ==============================================
// 参数定义(Q16格式)
// ==============================================
parameter SCALE     = 32'h00007AE1;    // 0.48的Q16.16定点数表示
parameter Y_OFFSET  = 16'd172;    // 172.0的Q16.16定点数表示

// 图像中心坐标(像素)
parameter IMG_CENTER_X = 320;
parameter IMG_CENTER_Y = 240;

// 形状编码定义
localparam SHAPE_IRREGULAR = 2'b00;  // 不规则
localparam SHAPE_HEXAGON   = 2'b01;  // 六边形
localparam SHAPE_CIRCLE    = 2'b10;  // 圆形
localparam SHAPE_SQUARE    = 2'b11;  // 正方形

// ==============================================
// 目标信息提取
// ==============================================
wire [9:0] left [3:0];    // 左边界（像素）
wire [9:0] right [3:0];   // 右边界（像素）
wire [9:0] top [3:0];     // 上边界（像素）
wire [9:0] bottom [3:0];  // 下边界（像素）
wire [3:0] target_valid;  // 目标有效标志
wire [1:0] shape_in [3:0]; // 目标形状输入

generate
    genvar k;
    for (k = 0; k < 4; k = k + 1) begin : TARGET_EXTRACT
        assign target_valid[k] = target_out[k][40];  // 第40位是有效标志
        assign shape_in[k] = target_out[k][42:41];  // 形状编码
        assign left[k]    = target_out[k][9:0];
        assign right[k]   = target_out[k][29:20];
        assign top[k]     = target_out[k][19:10];
        assign bottom[k]  = target_out[k][39:30];
    end
endgenerate

// ==============================================
// 中心坐标计算（像素）
// ==============================================
reg [15:0] center_x [3:0];
reg [15:0] center_y [3:0];

integer i;
always @(*) begin
    for (i = 0; i < 4; i = i + 1) begin
        center_x[i] = (left[i] + right[i]) / 2;
        center_y[i] = (top[i] + bottom[i]) / 2;
    end
end

// ==============================================
// 坐标转换（Q16计算，整数输出）
// ==============================================
reg [15:0] temp_x;  // Q16临时变量
reg [15:0] temp_y;  // Q16临时变量

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid <= 1'b0;
        temp_x <= 16'd0;
        temp_y <= 'd0;
    end else begin
        // 默认值
        valid <= 1'b0;
        
        // 遍历四个目标，找到形状匹配的有效目标
        for (i = 0; i < 4; i = i + 1) begin
            if (target_valid[i] && (shape_in[i] == target_shape)) begin
                temp_x <= center_x[i];
                temp_y <= center_y[i];
                valid <= 1'b1;
            end
        end
    end
end

assign real_x = valid ? (((temp_x- IMG_CENTER_X)*SCALE)>>16): 16'd0;
assign real_y = valid ? (((temp_y- IMG_CENTER_Y)*SCALE)>>16)+Y_OFFSET: 16'd0;

endmodule