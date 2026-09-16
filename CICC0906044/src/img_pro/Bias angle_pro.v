`timescale 1ns/1ns

module ShapeAngleProcessor (
    input         clk,                // 系统时钟
    input         rst_n,              // 异步复位（低电平有效）
    input  [1:0]  shape,              // 形状选择：00=三角形, 11=正方形
    input  [39:0] border,             // 边界坐标{left[9:0], top[9:0], right[9:0], bottom[9:0]}
    input  [9:0]  first_x,            // 起始点X坐标
    input  [9:0]  last_x,             // 结束点X坐标
    output reg [1:0] angle_mode,      // 角度计算模式：
                                     // [0]: 0=顺时针, 1=逆时针
                                     // [1]: 0=arctan, 1=45°-arctan
    output reg [1:0] shape_state,     // 形状状态：
                                     // 正方形：00=标准, 01=斜边
                                     // 三角形：00=左下, 01=左上, 10=右上, 11=右下
    output reg [9:0] a,               // 几何参数a（高度或宽度分量）
    output reg [9:0] b,               // 几何参数b（宽度或高度分量）
    output reg    data_valid           // 数据有效标志
);

// 边界坐标分解
wire [9:0] left   = border[39:30];
wire [9:0] top    = border[29:20];
wire [9:0] right  = border[19:10];
wire [9:0] bottom = border[9:0];

// 几何参数计算
wire [9:0] width  = right - left;
wire [9:0] height = top - bottom;
wire is_square = (width == height);  // 是否为标准正方形
wire is_wide   = (width > height);   // 是否为宽矩形

// 特征点检测（流水线寄存器）
reg at_left_first_x, at_right_first_x;
reg at_left_last, at_right_last;
reg is_diagonal;  // 正方形斜边标志

// 输入寄存器级（提高时序性能）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        at_left_first_x  <= 1'b0;
        at_right_first_x <= 1'b0;
        at_left_last     <= 1'b0;
        at_right_last    <= 1'b0;
        is_diagonal      <= 1'b0;
    end else begin
        at_left_first_x  <= (first_x == left);
        at_right_first_x <= (first_x == right);
        at_left_last     <= (last_x == left);
        at_right_last    <= (last_x == right);
        is_diagonal      <= (first_x != left) && (first_x != right); // 非左右边界为斜边
    end
end

// 主处理逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        angle_mode   <= 2'b00;
        shape_state  <= 2'b00;
        data_valid   <= 1'b0;
        a <= 10'd0;  
        b <= 10'd0;
    end else begin
        // 默认值
        data_valid <= 1'b0;
        
        case(shape)
            2'b11: begin // 正方形处理            
                if (is_diagonal) begin
                    // 斜边正方形：计算对角线角度
                    b <= right - last_x;  // 水平分量
                    a <= last_x - left;   // 垂直分量
                    angle_mode <= 2'b00;  // 顺时针arctan计算
                    shape_state <= 2'b01; // 斜边状态
                    data_valid <= 1'b1;
                end
                else begin
                    // 标准正方形
                    b <= width;
                    a <= height;
                    angle_mode <= 2'b00;  // 无角度计算
                    shape_state <= 2'b00; // 标准状态
                    data_valid <= 1'b1;
                end
            end 
            
            2'b00: begin // 三角形处理（完整8种情况）
                // === 情况1：左下直角（宽矩形+起点在左+终点在右） ===
                if (at_left_first_x && at_right_last && is_wide) begin
                    angle_mode  <= 2'b00;  // arctan((last_x-first_x)/height) 顺时针归位
                    shape_state <= 2'b00;  // 左下直角
                    b <= last_x - first_x; // 底边长度
                    a <= height;           // 高度
                    data_valid <= 1'b1;
                end 
                
                // === 情况2：左下直角（高矩形+起点在左+终点在右） ===
                else if (at_left_first_x && at_right_last && !is_wide) begin
                    angle_mode  <= 2'b11;  // 45°-arctan((last_x-first_x)/height) 逆时针归位
                    shape_state <= 2'b00;  // 左下直角
                    b <= last_x - first_x; 
                    a <= height;
                    data_valid <= 1'b1;
                end
                
                // === 情况3：左上直角（宽矩形+起点在左+终点在左） ===
                else if (at_left_first_x && at_left_last && is_wide) begin
                    angle_mode  <= 2'b01;  // arctan((first_x-last_x)/height) 逆时针归位 
                    shape_state <= 2'b01;  // 左上直角
                    b <= first_x - last_x; 
                    a <= height;
                    data_valid <= 1'b1;
                end
                
                // === 情况4：左上直角（高矩形+起点在右+终点在左） ===
                else if (at_right_first_x && at_left_last && !is_wide) begin
                    angle_mode  <= 2'b10;  // 45°-arctan((last_x-first_x)/height) 顺时针归位
                    shape_state <= 2'b01;  // 左上直角
                    b <= last_x - first_x; 
                    a <= height;
                    data_valid <= 1'b1;
                end
                
                // === 情况5：右上直角（宽矩形+起点在右+终点在右） ===
                else if (at_right_first_x && at_right_last && is_wide) begin
                    angle_mode  <= 2'b00;  // arctan((last_x-first_x)/height) 顺时针归位
                    shape_state <= 2'b10;  // 右上直角
                    b <= last_x - first_x; 
                    a <= height;
                    data_valid <= 1'b1;
                end
                
                // === 情况6：右上直角（高矩形+起点在左+终点在右） ===
                else if (at_left_first_x && at_right_last && !is_wide) begin
                    angle_mode  <= 2'b11;  // 45°-arctan((last_x-first_x)/height) 逆时针归位
                    shape_state <= 2'b10;  // 右上直角
                    b <= last_x - first_x; 
                    a <= height;
                    data_valid <= 1'b1;
                end
                
                // === 情况7：右下直角（高矩形+起点在右+终点在左） ===
                else if (at_right_first_x && at_left_last && !is_wide) begin
                    angle_mode  <= 2'b10;  // 45°-arctan((first_x-last_x)/height) 顺时针归位
                    shape_state <= 2'b11;  // 右下直角
                    b <= first_x - last_x; 
                    a <= height;
                    data_valid <= 1'b1;
                end
                
                // === 情况8：右下直角（宽矩形+起点在右+终点在左） ===
                else if (at_right_first_x && at_left_last && is_wide) begin
                    angle_mode  <= 2'b01;  // arctan((first_x-last_x)/height) 逆时针归位
                    shape_state <= 2'b11;  // 右下直角
                    b <= first_x - last_x; 
                    a <= height;
                    data_valid <= 1'b1;
                end
                
                // 未识别的情况
                else begin
                    angle_mode   <= 2'b00;
                    shape_state  <= 2'b00;
                    data_valid   <= 1'b0;
                    b <= 10'd0;  
                    a <= 10'd0;
                end
            end
            
            // 其他形状（保留扩展性）
            default: begin
                angle_mode   <= 2'b00;
                shape_state  <= 2'b00;
                data_valid   <= 1'b0;
                b <= 10'd0;  
                a <= 10'd0;
            end
        endcase
    end
end

endmodule