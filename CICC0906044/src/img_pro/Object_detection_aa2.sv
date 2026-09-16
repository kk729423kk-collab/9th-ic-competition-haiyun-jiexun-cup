`timescale 1ns / 1ps

module Object_detection_multi
#(
    // 图像参数
    parameter IMG_HDISP = 640,    // 图像水平分辨率
    parameter IMG_VDISP = 480,    // 图像垂直分辨率
    parameter MAX_TARGETS = 4,     // 最大检测目标数
    
    // 检测参数
    parameter MIN_DIST = 10,       // 目标合并最小距离
    parameter MIN_TARGET_SIZE = 50, // 有效目标最小像素数
    
    // 形状面积阈值
    parameter AREA_SQUARE_MIN = 3500,
    parameter AREA_SQUARE_MAX = 4500,
    parameter AREA_CIRCLE_MIN = 2500,
    parameter AREA_CIRCLE_MAX = 3500,
    parameter AREA_TRIANGLE = 1750 // 三角形面积阈值（正方形一半）
)(
    // 系统接口
    input         Clk,
    input         Rst_n,
    
    // 视频输入接口
    input         valid_i,
    input         img_data_i,
    
    // 目标输出接口
    output reg [40:0] location_o [0:MAX_TARGETS-1], // 目标边界信息
    output reg [15:0] X        [0:MAX_TARGETS-1],   // 图像中心X坐标
    output reg [15:0] Y        [0:MAX_TARGETS-1],   // 图像中心Y坐标
    output reg [3:0]  Shape    [0:MAX_TARGETS-1],   // 形状编码
    output reg [15:0] Area     [0:MAX_TARGETS-1],   // 目标面积
    output reg [3:0]  target_count,                // 检测目标数量
    output reg        data_valid                   // 数据有效标志
);

    // 形状编码定义
    localparam SHAPE_HEX    = 4'b0001;
    localparam SHAPE_SQUARE = 4'b0010;
    localparam SHAPE_CIRCLE = 4'b0100;
    localparam SHAPE_TRI    = 4'b1000;

    // 内部信号
    reg [9:0] x_cnt, y_cnt;
    reg frame_end, frame_end_r;
    wire vsync_pos_flag = frame_end & ~frame_end_r;
    
    // 目标管理
    reg [40:0] current_locations [0:MAX_TARGETS-1];
    reg [15:0] current_pixel_cnt [0:MAX_TARGETS-1];
    reg [3:0]  target_active;

    // 像素坐标计数
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            x_cnt <= 0;
            y_cnt <= 0;
            frame_end <= 0;
            frame_end_r <= 0;
        end else begin
            frame_end_r <= frame_end;
            if (valid_i) begin
                x_cnt <= (x_cnt == IMG_HDISP-1) ? 0 : x_cnt + 1;
                if (x_cnt == IMG_HDISP-1)
                    y_cnt <= (y_cnt == IMG_VDISP-1) ? 0 : y_cnt + 1;
            end
            frame_end <= valid_i && (x_cnt == IMG_HDISP-1) && (y_cnt == IMG_VDISP-1);
        end
    end

    // 多目标检测核心
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            for (integer i=0; i<MAX_TARGETS; i=i+1) begin
                current_locations[i] <= 0;
                current_pixel_cnt[i] <= 0;
                target_active[i] <= 0;
            end
        end else if (vsync_pos_flag) begin
            for (integer i=0; i<MAX_TARGETS; i=i+1) begin
                current_locations[i] <= 0;
                current_pixel_cnt[i] <= 0;
                target_active[i] <= 0;
            end
        end else if (valid_i && img_data_i) begin
            reg target_found;
            target_found = 0;
            
            // 检查现有目标
            for (integer i=0; i<MAX_TARGETS; i=i+1) begin
                if (target_active[i]) begin
                    reg [15:0] width, height;
                    width = current_locations[i][29:20] - current_locations[i][9:0];
                    height = current_locations[i][39:30] - current_locations[i][19:10];
                    
                    if ((x_cnt >= current_locations[i][9:0] - (width>>3)) && 
                       (x_cnt <= current_locations[i][29:20] + (width>>3)) &&
                       (y_cnt >= current_locations[i][19:10] - (height>>3)) && 
                       (y_cnt <= current_locations[i][39:30] + (height>>3))) begin
                       
                        // 更新边界
                        current_locations[i][9:0]   <= (x_cnt < current_locations[i][9:0]) ? x_cnt : current_locations[i][9:0];
                        current_locations[i][29:20] <= (x_cnt > current_locations[i][29:20]) ? x_cnt : current_locations[i][29:20];
                        current_locations[i][19:10] <= (y_cnt < current_locations[i][19:10]) ? y_cnt : current_locations[i][19:10];
                        current_locations[i][39:30] <= (y_cnt > current_locations[i][39:30]) ? y_cnt : current_locations[i][39:30];
                        
                        current_pixel_cnt[i] <= current_pixel_cnt[i] + 1;
                        target_found = 1;
                        break;
                    end
                end
            end
            
            // 创建新目标
            if (!target_found) begin
                for (integer i=0; i<MAX_TARGETS; i=i+1) begin
                    if (!target_active[i]) begin
                        current_locations[i] <= {1'b1, y_cnt, x_cnt, y_cnt, x_cnt};
                        current_pixel_cnt[i] <= 1;
                        target_active[i] <= 1;
                        break;
                    end
                end
            end
        end
    end
integer cnt;
    // 形状识别与输出
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            target_count <= 0;
            data_valid <= 0;
            for (integer i=0; i<MAX_TARGETS; i=i+1) begin
                location_o[i] <= 0;
                X[i] <= 0;
                Y[i] <= 0;
                Shape[i] <= SHAPE_HEX;
                Area[i] <= 0;
            end
        end else if (vsync_pos_flag) begin
            cnt=0;
            for (integer i=0; i<MAX_TARGETS; i=i+1) begin
                if (target_active[i] && (current_pixel_cnt[i] > MIN_TARGET_SIZE)) begin
                    // 计算中心坐标
                    X[i] <= (current_locations[i][9:0] + current_locations[i][29:20]) >> 1;
                    Y[i] <= (current_locations[i][19:10] + current_locations[i][39:30]) >> 1;
                    Area[i] <= current_pixel_cnt[i];
                    
                    // 形状识别
                    if (current_pixel_cnt[i] >= AREA_SQUARE_MIN && 
                        current_pixel_cnt[i] <= AREA_SQUARE_MAX) begin
                        Shape[i] <= SHAPE_SQUARE;
                    end else if (current_pixel_cnt[i] >= AREA_CIRCLE_MIN && 
                               current_pixel_cnt[i] <= AREA_CIRCLE_MAX) begin
                        Shape[i] <= SHAPE_CIRCLE;
                    end else if (current_pixel_cnt[i] >= AREA_TRIANGLE && 
                               current_pixel_cnt[i] < AREA_CIRCLE_MIN) begin
                        Shape[i] <= SHAPE_TRI;
                    end else begin
                        Shape[i] <= SHAPE_HEX;
                    end
                    
                    cnt = cnt + 1;
                end else begin
                    Shape[i] <= SHAPE_HEX;
                    Area[i] <= 0;
                end
            end
            target_count <= cnt;
            data_valid <= 1;
        end else begin
            data_valid <= 0;
        end
    end

endmodule