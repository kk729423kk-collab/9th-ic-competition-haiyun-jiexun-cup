`timescale 1ns / 1ps

module img_pro
(
    // 系统接口
    input               Clk,          // 系统时钟 (74.25MHz)
    input               Rst_n,        // 异步复位 (低有效)
    
    // 摄像头输入
    input               vsync,        // 场同步信号
    input               href,         // 行同步信号
    input               vld,          // 数据有效标志
    input       [23:0]  data_in,      // RGB888像素数据
    input       [15:0]  data_in1,
    input       [1:0]   target_shape,
    
    // 处理输出
    output [23:0]       center_hsv,   // 中心区域HSV均值
    output              img_vld,      // 输出图像有效标志
    output [15:0]       img_data,     // 标记后的RGB图像
    output [3:0]        target_vld,
    output [13:0]       area_out[3:0],
    output [1:0]        shape,
    output wire [15:0]  real_x,       // X坐标(整数mm)
    output wire [15:0]  real_y        // Y坐标(整数mm)
);

    //---------------- 参数定义 -----------------//
    parameter [10:0] IMG_HDISP = 11'd640;  // 图像水平分辨率
    parameter [10:0] IMG_VDISP = 11'd480;  // 图像垂直分辨率

    //---------------- 信号声明 -----------------//
    // HSV转换输出
    wire        hsv_vs, hsv_hs, hsv_vld;
    wire [23:0] hsv_out;
    
    // 二值化输出
    wire        bin_vs, bin_hs, bin_vld;
    wire        bin_out;
    
    // 形态学处理
    wire        erode_vsync, erode_href, erode_clken, erode_bit;
    wire        dilate_vsync, dilate_href, dilate_vld, dilate_bit;
    
    // 目标检测信号
    wire [42:0] target_out [0:3];     // 目标信息（包含形状和有效性）
  

    //---------------- 模块实例化 -----------------//

    // RGB转HSV模块
    RGB2HSV RGB2HSV_inst (
        .Clk        (Clk),
        .Rst        (~Rst_n),
        .vs         (vsync),
        .hs         (href),
        .valid_i    (vld),
        .rgb_data_i (data_in),
        .hsv_vs     (hsv_vs),
        .hsv_hs     (hsv_hs),
        .valid_o    (hsv_vld),
        .center_hsv (center_hsv),
        .hsv_data_o (hsv_out)
    );

    // HSV二值化模块
    HSV_binarization HSV_binarization_inst (
        .Clk          (Clk),
        .Rst_n        (Rst_n),
        .hsv_h        (hsv_out[23:16]),
        .hsv_s        (hsv_out[15:8]),
        .hsv_v        (hsv_out[7:0]),
        .hsv_vs       (hsv_vs),
        .hsv_hs       (hsv_hs),
        .hsv_vld      (hsv_vld),
        .binary_pixel (bin_out),
        .vs_out       (bin_vs),
        .hs_out       (bin_hs),
        .vld_out      (bin_vld)
    );

    // 单次腐蚀处理（修改为1次腐蚀）
    Bit_Erosion_Detector #(
        .IMG_HDISP(IMG_HDISP),
        .IMG_VDISP(IMG_VDISP)
    ) u_Erosion (
        .clk               (Clk),
        .rst_n             (Rst_n),
        .per_frame_vsync   (bin_vs),
        .per_frame_href    (bin_hs),
        .per_frame_clken   (bin_vld),
        .per_img_Bit       (bin_out),
        .post_frame_vsync  (erode_vsync),
        .post_frame_href   (erode_href),
        .post_frame_clken  (erode_clken),
        .post_img_Bit      (erode_bit)
    );

    // 一级膨胀处理
    Bit_Dilation_Detector #(
        .IMG_HDISP(IMG_HDISP),
        .IMG_VDISP(IMG_VDISP)
    ) u_Dilation (
        .clk               (Clk),
        .rst_n             (Rst_n),
        .per_frame_vsync   (erode_vsync),
        .per_frame_href    (erode_href),
        .per_frame_clken   (erode_clken),
        .per_img_Bit       (erode_bit),
        .post_frame_vsync  (dilate_vsync),
        .post_frame_href   (dilate_href),
        .post_frame_clken  (dilate_vld),
        .post_img_Bit      (dilate_bit)
    );

    // 目标检测和形状识别
    assign target_vld = {target_out[0][40], target_out[1][40], target_out[2][40], target_out[3][40]};
    assign shape = target_out[0][42:41];
    
    shape_recognition u_shape_recognition(
        .clk              (Clk),
        .rst_n            (Rst_n),
        .per_frame_vsync  (dilate_vsync),
        .per_frame_href   (dilate_href),
        .per_frame_clken  (dilate_vld),
        .per_img_Bit      (dilate_bit),
        .target_out       (target_out),
        .area_out         (area_out),
        .MIN_DIST         (6)
    );

    // 绘制边界框
    wire [15:0] out_img_Y;
    VIP_Video_add_rectangular u_VIP_Video_add_rectangular(
        .clk              (Clk),
        .rst_n            (Rst_n),
        .per_frame_vsync  (vsync),
        .per_frame_href   (href),
        .per_frame_clken  (vld),
        .in_img           (data_in1),
        .flag             (4'd1),
        .up_pos           (46),
        .down_pos         (405),
        .left_pos         (32),
        .right_pos        (572),
        .target_out       (target_out),
        .post_frame_vsync (post4_frame_vsync),
        .post_frame_href  (post4_frame_href),
        .post_frame_clken (post4_frame_clken),
        .out_img_Y        (out_img_Y)
    );

    // 坐标计算
    data_ctrl data_ctrl_inst(
        .clk          (Clk),
        .rst_n        (Rst_n),
        .target_out   (target_out),
        .target_shape (target_shape),
        .real_x       (real_x),
        .real_y       (real_y),
        .valid        ()
    );

    // 输出连接
    assign img_vld = post4_frame_clken;
    assign img_data = out_img_Y;

endmodule