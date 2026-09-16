`timescale 1ns / 1ps

module Video_Marker
#(
    parameter IMG_HDISP = 640,    // 图像水平分辨率
    parameter IMG_VDISP = 480,    // 图像垂直分辨率
    parameter MAX_TARGETS = 4,     // 最大目标数量
    parameter BOX_COLOR = 16'hF800,  // 默认边界框颜色（红色）
    parameter LINE_WIDTH = 2         // 边界框线宽
)(
    // 系统接口
    input         clk,
    input         rst_n,
    
    // 原始视频输入（RGB888格式）
    input         video_vsync_i,   // 场同步
    input         video_hsync_i,   // 行同步
    input         video_de_i,      // 数据有效
    input  [23:0] video_data_i,    // RGB888格式
    
    // 目标检测接口
    input         detect_valid_i,  // 检测数据有效
    input [40:0]  detect_boxes_i [0:MAX_TARGETS-1], // 目标边界[x_min,y_min,x_max,y_max]
    input [3:0]   detect_shapes_i [0:MAX_TARGETS-1], // 形状编码
    input [3:0]   target_count_i,  // 有效目标数
    
    // 视频输出（RGB565格式）
    output reg        video_vsync_o,
    output reg        video_hsync_o,
    output reg        video_de_o,
    output reg [15:0] video_data_o
);

    // 视频流水线寄存器
    reg [9:0] pixel_x;  // 当前像素X坐标
    reg [9:0] pixel_y;  // 当前像素Y坐标
    
    // 形状颜色映射（RGB565格式）
    reg [15:0] box_color_map [0:3];
    initial begin
        box_color_map[0] = 16'hF800; // 六边形-红色
        box_color_map[1] = 16'h07E0; // 正方形-绿色
        box_color_map[2] = 16'h001F; // 圆形-蓝色
        box_color_map[3] = 16'hFFE0; // 三角形-黄色
    end

    // RGB888转RGB565转换
    wire [15:0] rgb565_data;
    assign rgb565_data = {
        video_data_i[23:19],  // R[4:0]
        video_data_i[15:10],  // G[5:0]
        video_data_i[7:3]     // B[4:0]
    };

    // 视频时序生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_x <= 0;
            pixel_y <= 0;
        end else begin
            if (video_de_i) begin
                pixel_x <= (pixel_x == IMG_HDISP-1) ? 0 : pixel_x + 1;
                if (pixel_x == IMG_HDISP-1)
                    pixel_y <= (pixel_y == IMG_VDISP-1) ? 0 : pixel_y + 1;
            end
        end
    end
 reg [9:0] x_min ;
 reg [9:0] y_min ;
 reg [9:0] x_max ;
 reg [9:0] y_max ;
    // 边界框绘制核心逻辑
    always @(posedge clk) begin
        // 保持同步信号延迟一致性
        video_vsync_o <= video_vsync_i;
        video_hsync_o <= video_hsync_i;
        video_de_o    <= video_de_i;
        
        // 默认输出转换后的RGB565数据
        video_data_o <= rgb565_data;
        
        // 遍历所有有效目标
        for (int i=0; i<MAX_TARGETS; i=i+1) begin
            if (i < target_count_i) begin
                // 解析目标边界参数
               x_min = detect_boxes_i[i][9:0];
               y_min = detect_boxes_i[i][19:10];
               x_max = detect_boxes_i[i][29:20];
               y_max = detect_boxes_i[i][39:30];
                
                // 边界框绘制条件判断
                if (
                    (pixel_x >= (x_min - LINE_WIDTH) && 
                     pixel_x <= (x_max + LINE_WIDTH)) && 
                    (
                        // 上边框
                        (pixel_y >= y_min - LINE_WIDTH && 
                         pixel_y <= y_min + LINE_WIDTH) ||
                        // 下边框
                        (pixel_y >= y_max - LINE_WIDTH && 
                         pixel_y <= y_max + LINE_WIDTH) ||
                        // 左边框
                        (pixel_x >= x_min - LINE_WIDTH && 
                         pixel_x <= x_min + LINE_WIDTH) ||
                        // 右边框
                        (pixel_x >= x_max - LINE_WIDTH && 
                         pixel_x <= x_max + LINE_WIDTH)
                    )
                )
                begin
                    // 根据形状选择颜色（RGB565）
                    case(detect_shapes_i[i])
                        4'b0001: video_data_o <= box_color_map[0]; // 六边形
                        4'b0010: video_data_o <= box_color_map[1]; // 正方形
                        4'b0100: video_data_o <= box_color_map[2]; // 圆形
                        4'b1000: video_data_o <= box_color_map[3]; // 三角形
                        default: video_data_o <= BOX_COLOR;       // 默认红色
                    endcase
                end
            end
        end
    end

endmodule