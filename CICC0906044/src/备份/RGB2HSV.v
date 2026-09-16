`timescale 1ns / 1ps

module RGB2HSV(
    input  wire       Clk,         // 像素时钟（典型值：74.25MHz for 1080p60）
    input  wire       Rst,         // 异步复位（高电平有效）
    input  wire       vs,          // 输入场同步信号（垂直同步）
    input  wire       hs,          // 输入行同步信号（水平同步）
    input  wire       valid_i,     // 输入数据有效标志
    input  wire [23:0] rgb_data_i, // RGB888输入数据（格式：{R[7:0], G[7:0], B[7:0]}）
    
    output wire       hsv_vs,      // 输出场同步信号（与HSV数据对齐）
    output wire       hsv_hs,      // 输出行同步信号
    output wire       valid_o,     // 输出数据有效标志（除法器完成后拉高）
    output wire [23:0] hsv_data_o, // HSV输出数据（格式：{H[7:0], S[7:0], V[7:0]}）
    output wire [23:0] center_hsv  // 新增：屏幕中心点的HSV参数
);

    ///////////////////////////////////////////////
    // 变量声明与功能说明
    ///////////////////////////////////////////////
    wire [7:0] R, G, B;          // RGB分量（直接从输入拆分）
    assign {R, G, B} = rgb_data_i;

    // 流水线控制信号
    reg valid_d1, valid_d2;       // 有效信号延迟寄存器

    // Stage 1 寄存器
    reg [7:0] var_Min, var_Max;   // RGB最小/最大值
    reg [8:0] var_Ext;            // 扩展值（用于H计算，带符号位）
    reg [1:0] var_Max_id;         // 最大值来源标识（0:R, 1:G, 2:B）
    reg [7:0] R_d1, G_d1, B_d1;   // RGB分量延迟（用于后续计算）

    // Stage 2 寄存器
    wire [7:0] del_Max_w;         // Delta = var_Max - var_Min
    reg [15:0] del_Max_m255;      // Delta * 255（用于S计算）
    reg [10:0] del_Max_m6;        // Delta * 6（用于H计算）
    reg [7:0] var_Max_d1;         // var_Max延迟（对齐时序）
    wire [10:0] H_w;              // 色相分子（有符号扩展）
    reg [18:0] H_del;             // 色相分子 * 256（预移位）

    // Stage 3 寄存器
    reg [8*9-1:0] var_Max_d1_shift_r; // var_Max的移位寄存器（用于V延迟对齐）

    // 除法器输出
    wire s_div_valid_w;           // S计算完成标志
    wire [7:0] S;                 // 饱和度（0-255）
    wire h_div_valid_w;           // H计算完成标志
    wire [7:0] H;                 // 色相（0-359缩放到0-255）
    wire [7:0] V;                 // 明度（直接取自var_Max）

    // 同步信号延迟链
    reg [10:0] vs_delay, hs_delay; // 同步信号延迟寄存器（对齐数据路径）

    // 新增：用于重新生成坐标的寄存器
    reg [9:0] new_x_cnt;  // 新的行内像素计数（0-639）
    reg [9:0] new_y_cnt;  // 新的场内行计数（0-479）

    // 新增：存储中心点HSV的寄存器
    reg [23:0] center_hsv_reg;
    reg center_detected;

    ///////////////////////////////////////////////
    // Stage 1: 计算RGB极值和扩展值
    ///////////////////////////////////////////////
    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            valid_d1 <= 0;
            {var_Min, var_Max} <= 0;
            var_Ext <= 0;
            var_Max_id <= 0;
            {R_d1, G_d1, B_d1} <= 0;
           
            
 
        end else begin
            valid_d1 <= valid_i;  // 传递有效信号

            if (valid_i) begin
                // 计算最小值（三级比较树优化时序）
                var_Min <= (R > G) ? ((G > B) ? B : G) : ((R > B) ? B : R);

                // 计算最大值并记录来源
                if (R > G) begin
                    if (R > B) begin       // R为最大值
                        var_Max <= R;
                        var_Max_id <= 0;
                        var_Ext <= (G > B) ? G - B : 0;  // 正值处理
                    end else begin         // B为最大值
                        var_Max <= B;
                        var_Max_id <= 2;
                        var_Ext <= R - {1'b0, G};       // 可能有负值
                    end
                end else if (G > B) begin  // G为最大值
                    var_Max <= G;
                    var_Max_id <= 1;
                    var_Ext <= B - {1'b0, R};           // 可能有负值
                end else begin             // B为最大值
                    var_Max <= B;
                    var_Max_id <= 2;
                    var_Ext <= R - {1'b0, G};           // 可能有负值
                end

                // 缓存RGB分量（用于后续计算）
                {R_d1, G_d1, B_d1} <= {R, G, B};
            end
        end
    end

    ///////////////////////////////////////////////
    // Stage 2: 预计算中间值
    ///////////////////////////////////////////////
    assign del_Max_w = var_Max - var_Min;  // Delta = V - min(R,G,B)

    // 色相分子计算（有符号处理）
    assign H_w = (var_Max_id == 0) ? {2'b0, var_Ext} :           // R最大：H = (G-B)/Delta
                 (var_Max_id == 1) ? ({del_Max_w, 1'b0} + {{2{var_Ext[8]}}, var_Ext}) :  // G最大：H = 2 + (B-R)/Delta
                 ({del_Max_w, 2'b0} + {{2{var_Ext[8]}}, var_Ext}); // B最大：H = 4 + (R-G)/Delta

    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            valid_d2 <= 0;
            del_Max_m255 <= 0;
            del_Max_m6 <= 0;
            H_del <= 0;
            var_Max_d1 <= 0;
        end else begin
            valid_d2 <= valid_d1;  // 传递有效信号

            if (valid_d1) begin
                // 预计算 Delta*255（用于饱和度S）
                del_Max_m255 <= {del_Max_w, 8'b0} - del_Max_w;  // 等价于 delta*255

                // 预计算 Delta*6（用于色相H）
                del_Max_m6 <= {del_Max_w, 2'b0} + {del_Max_w, 1'b0};  // delta*4 + delta*2

                // 色相分子预移位（H_w * 256，提高除法精度）
                H_del <= (H_w[10] || (del_Max_w == 0)) ? 0 : {H_w, 8'b0} - H_w;

                // 传递最大值（用于明度V）
                var_Max_d1 <= var_Max;
            end
        end
    end

    ///////////////////////////////////////////////
    // Stage 3: 除法计算与输出对齐
    ///////////////////////////////////////////////

    // var_Max延迟链（用于对齐V输出）
    always @(posedge Clk) begin
        var_Max_d1_shift_r <= {var_Max_d1_shift_r, var_Max_d1};  // 9级延迟
    end
    assign V = var_Max_d1_shift_r[8*9-1:8*8];  // 取第9个寄存器的值

    // 饱和度S = (Delta*255) / var_Max
    divide #(
       .I_W(16),  // 输入位宽（dividend）
       .D_W(8)    // 除数位宽
    ) u_divide_S (
       .Clk      (Clk),
       .Rst      (Rst),
       .valid_i  (valid_d2),
       .dividend (del_Max_m255),  // Delta*255
       .divisor  (var_Max_d1),     // var_Max
       .valid_o  (s_div_valid_w),  // 计算完成标志
       .quotient (S),              // 饱和度输出（0-255）
       .remaind  ()                // 余数（未使用）
    );

    // 色相H = (H_w * 60) / (6*Delta) = (H_w * 10) / Delta
    divide #(
       .I_W(19),  // 输入位宽（H_del为19-bit）
       .D_W(11)   // 除数位宽（del_Max_m6为11-bit）
    ) u_divide_H (
       .Clk      (Clk),
       .Rst      (Rst),
       .valid_i  (valid_d2),
       .dividend (H_del),         // H_w * 256
       .divisor  (del_Max_m6),     // Delta * 6
       .valid_o  (h_div_valid_w),  // 计算完成标志
       .quotient (H),              // 色相输出（0-359缩放到0-255）
       .remaind  ()
    );

    // 输出赋值
    assign valid_o = s_div_valid_w;  // 使用S的有效标志（与H同步）
    assign hsv_data_o = {H, S, V};   // 拼接HSV输出

    // 重新生成x、y坐标
    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            new_x_cnt <= 0;
            new_y_cnt <= 0;
        end else if (valid_o) begin
            if (new_x_cnt < 639) begin
                new_x_cnt <= new_x_cnt + 1'b1;
            end else begin
                new_x_cnt <= 0;
                if (new_y_cnt < 479) begin
                    new_y_cnt <= new_y_cnt + 1'b1;
                end else begin
                    new_y_cnt <= 0;
                end
            end
        end
    end

    // 当检测到中心点且数据有效时，存储当前的HSV值
    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            center_hsv_reg <= 0;
        end else if (valid_o && new_x_cnt == 320 && new_y_cnt == 240) begin
            center_hsv_reg <= {H, S, V};
        end
    end

    // 输出中心点的HSV值
    assign center_hsv = center_hsv_reg;

    ///////////////////////////////////////////////
    // 同步信号延迟对齐（匹配计算流水线延迟）
    ///////////////////////////////////////////////
    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            vs_delay <= 0;
            hs_delay <= 0;
        end else begin
            vs_delay <= {vs_delay[9:0], vs};  // 11级延迟
            hs_delay <= {hs_delay[9:0], hs};
        end
    end

    assign hsv_vs = vs_delay[10];  // 取第11个寄存器的值
    assign hsv_hs = hs_delay[10];

endmodule