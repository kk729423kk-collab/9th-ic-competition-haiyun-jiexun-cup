`timescale 1ns / 1ps

// 逆运动学模块（Inverse_kinematics_ak）
// 功能：根据机械臂末端坐标(X,Y,Z)计算机械臂各关节角度(J0-J3)
// 输入：末端坐标(X,Y,Z)、方形尺寸(height_r,width_r)、调整信号(update_rac,adjust)
// 输出：关节角度(J0-J3)、偏移角度(Offset_angle)、有效标志(valid)
module Inverse_kinematics_ak(
    // 系统信号
    input           Clk,        // 系统时钟
    input           Rst_n,      // 异步复位（低电平有效）
    
    // 位置输入
    input           update,     // 坐标更新信号
    input signed [15:0] X,      // 末端X坐标（有符号）
    input signed [15:0] Y,      // 末端Y坐标（有符号）
    input signed [15:0] Z,      // 末端Z坐标（有符号）
    
    // 方形尺寸输入（用于角度偏移计算）
    input     [7:0] height_r,   // 检测到的高度
    input     [7:0] width_r,    // 检测到的宽度
    input           update_rac, // 尺寸更新信号
    input     [6:0] adjust,     // 调整参数
    
    // 关节角度输出
    output reg signed [11:0] J0,        // 关节0角度
    output reg signed [11:0] J1,        // 关节1角度
    output reg signed [11:0] J2,        // 关节2角度
    output reg signed [11:0] J3,        // 关节3角度
    output reg signed [11:0] Offset_angle, // 方形偏移角度
    output reg           valid           // 计算结果有效标志
);
    localparam
        L0 = 'd86,   // 底座高度
        L1 = 'd155,  // 长臂长度
        L2 = 'd143,   // 短臂长度
        L3 = 'd140;  // 抓取臂长度
    
    // 预计算常数（用于余弦定理）
    parameter Q1 = 'd24025;  // L1^2 = 105^2 = 11025
    parameter Q2 = 'd20449;   // L2^2 = 74^2 = 5476

////////////////////////////////////////// 寄存器定义
    reg     [11:0] Theta_1, Theta_2, Theta_3, J0r2; // 中间角度变量
    reg     [15:0] L4, L5;       // L4:垂直投影长度 L5:斜边长度
    reg     [11:0] J0r, J1r, J2r, J3r; // 关节角度中间值
    reg     [23:0] in_data_1, in_data_2; // 平方运算中间数据
    reg signed [11:0] cos_theta_1, cos_theta_2, cos_theta_3; // 余弦值
    reg signed [15:0] cos_theta_0; // 基础余弦值
    reg signed [17:0] Q5, Q12, Q15; // 中间计算结果
    reg signed [18:0] Q125, Q152;   // 中间计算结果
    
    // 有效信号移位寄存器
    reg     [4:0] valid_s_r, valid_a_r;
    
    // 平方根计算相关信号
    reg valid_s, valid_s_r2, update_s, update_r, finish_s_r;
    reg [23:0] IN_DATA;
    reg [2:0] cnt_s, step_s;
    wire finish_s;
    wire [15:0] OUT_DATA;
    
    // 反余弦计算相关信号
    reg valid_a, valid_a_r2;
    reg [11:0] cos_theta;
    reg [3:0] step_a;

    // 除法器相关信号
    reg valid_d;
    reg [3:0] step_d;
    reg [2:0] valid_d_r;
    reg [17:0] denom;
    reg [27:0] numer;
    wire [27:0] quotient;
    
    // ROM查找表相关
    reg [10:0] address;
    wire [11:0] q;
    
     reg signed [6:0] adjust3,adjust0;
    //反正切计算相关
    reg signal; // 符号标志：0:正 1:负
    reg [11:0] tan_theta, tan_theta_r;
    reg [10:0] address_atan_rom;
    reg [3:0] cnt_at;
    reg [15:0] denom_r;
    reg [25:0] numer_r;
    reg [7:0] height, width;
    wire [11:0] q_atan_rom;

////////////////////////////////////////// 同步逻辑
    always@(posedge Clk) begin
        // 输出有效信号
        valid <= (!Rst_n) ? 0 : valid_a_r[4];
        
        // 同步寄存器
        update_r <= (!Rst_n) ? 0 : update;
        finish_s_r <= (!Rst_n) ? 0 : finish_s;
        
        // 有效信号移位寄存器
        valid_s_r <= (!Rst_n) ? 0 : {valid_s_r[3:0], valid_s};
        valid_a_r <= (!Rst_n) ? 0 : {valid_a_r[3:0], valid_a};
        valid_d_r <= (!Rst_n) ? 0 : {valid_d_r[1:0], valid_d};
    end
    
    // 有效信号控制
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            valid_s_r2 <= 'b0;
            valid_a_r2 <= 'b0;
        end
        else if({valid_s_r2, valid_a_r2} == 2'b11) begin
            valid_s_r2 <= 'b0;
            valid_a_r2 <= 'b0;
        end
        else begin
            valid_s_r2 <= valid_s ? 1 : valid_s_r2;
            valid_a_r2 <= valid_a ? 1 : valid_a_r2;
        end    
    end

////////////////////////////////////////// L4与L5计算（投影长度和斜边长度）
    // 计算中间值：X²+Y² 和 L4²+(L3+Z-L0)²
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            in_data_1 <= 'b0;
            in_data_2 <= 'b0;
        end
        else begin
            in_data_1 <= X*X + Y*Y;  // X²+Y²
            in_data_2 <= (cnt_s == 2) ? L4*L4 + (L3+Z-L0)*(L3+Z-L0) : in_data_2;
        end
    end
    
    // 平方根计算模块实例化
    sqrt_ctrl sqrt_ctrl(
        .Clk(Clk),
        .Rst_n(Rst_n),
        .update(update_s),
        .IN_DATA(IN_DATA),
        .finish(finish_s),
        .OUT_DATA(OUT_DATA)
    );    
    
    // 平方根计算控制状态机
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            cnt_s <= 'b1;
            valid_s <= 'b0;
        end
        else if(update) begin
            cnt_s <= 'b1;
            valid_s <= 'b0;
        end
        else if(finish_s)
            cnt_s <= cnt_s + 1'b1;
        else if(cnt_s == 'd4) begin
            valid_s <= 'b1;
            cnt_s <= 'b1;
        end
        else
            valid_s <= 'b0;
    end
    
    // 平方根计算步骤控制
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            update_s <= 'd0;
            IN_DATA <= 'd0;
            step_s <= 'd0;
        end
        else begin
            case(step_s)
                'd0: begin
                    update_s <= 'd0;
                    IN_DATA <= IN_DATA;
                    step_s <= (update_r || finish_s_r) ? cnt_s : 'd0;
                end
                'd1: begin  // 计算sqrt(X²+Y²)
                    update_s <= 'd1;
                    IN_DATA <= in_data_1;
                    step_s <= 'd0;
                end
                'd2: begin  // 无操作
                    update_s <= 'd1;
                    step_s <= 'd0;
                end
                'd3: begin  // 计算sqrt(L4²+(L3+Z-L0)²)
                    update_s <= 'd1;
                    IN_DATA <= in_data_2;
                    step_s <= 'd0;
                end
                'd4: begin  // 无操作
                    step_s <= 'd0;
                end
                default: step_s <= 'd0;
            endcase
        end
    end
    
    // 存储计算结果
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            L4 <= 'b0;
            L5 <= 'b0;
        end
        else if(cnt_s == 'd2)  // 存储L4（投影长度）
            L4 <= OUT_DATA ;  // 减去补偿值
        else if(cnt_s == 'd4)  // 存储L5（斜边长度）
            L5 <= OUT_DATA;
    end
    
    // 动态调整补偿值（根据距离）
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n)
        begin
            adjust3 <= 0;
            adjust0 <= 'd20;
        end
        else if(cnt_s == 'd4) begin
            if(L4 >= 260)
            begin
                adjust3 <= 'd20;
                adjust0 <= 'd30;
            end
            else if(L4>250)
            begin
                adjust3 <= 'd20;
                adjust0 <= 'd10;
            end
            else if(L4>242)
            begin
                adjust3 <= 'd20;
                adjust0 <= 'd20;
            end
            else if(L4>225)
            begin
                adjust3 <= 'd40;
                adjust0 <= 'd10;
            end
            else if(L4>205)
            begin
                adjust3 <= 'd40;
                adjust0 <= 'd10;
            end
            else if(L4>196)
            begin
                adjust3 <= 'd40;
                adjust0 <= 'd20;
            end
            else if(L4>130) begin
                adjust3 <= 'd40;
                adjust0 <= 'd20;           
            end
            else  begin
                adjust3 <= -7'sd20;
                adjust0 <= 'd20;           
            end
        end
    end 

////////////////////////////////////////// 余弦定理相关计算
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            Q5 <= 'b0;
            Q12 <= 'b0;
            Q15 <= 'b0;
            Q125 <= 'b0;
            Q152 <= 'b0;
        end
        else if(valid_s) begin  // 计算L5², L1*L2, L1*L5
            Q5 <= L5 * L5;
            Q12 <= L1 * L2;
            Q15 <= L1 * L5;
        end
        else if(valid_s_r[0]) begin  // 计算余弦定理中间值
            Q125 <= Q1 + Q2 - Q5;  // L1² + L2² - L5²
            Q152 <= Q1 + Q5 - Q2;  // L1² + L5² - L2²
        end
    end
    
    // 余弦值计算状态机（使用除法器）
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            denom <= 'b1;
            numer <= 'b1;
            step_d <= 'b0;
            valid_d <= 'b0;
            cos_theta_0 <= 'b0;
            cos_theta_1 <= 'b0;
            cos_theta_2 <= 'b0;
            cos_theta_3 <= 'b0;
            tan_theta <= 'b0;
        end
        else begin
            case(step_d)
                'd0: begin  // 等待启动
                    step_d <= valid_s_r[3] ? 'd1 : 'd0;
                    valid_d <= 'b0;
                end
                'd1: begin  // 计算cosθ0 = Y/(L4+adjust)
                    denom <= L4 ;
                    numer <= X * 1000;  // 放大1000倍保持精度
                    step_d <= 'd2;
                end
                'd2: begin  // 计算cosθ1 = (L1²+L5²-L2²)/(2*L1*L5)
                    denom <= Q15;
                    numer <= Q152 * 500;  // 500=1000/2
                    step_d <= 'd3;
                end
                'd3: begin  // 计算cosθ2 = L4/L5
                    denom <= L5;
                    numer <= L4 * 1000;
                    step_d <= 'd4;
                end
                'd4: begin  // 计算cosθ3 = (L1²+L2²-L5²)/(2*L1*L2)
                    denom <= Q12;
                    numer <= Q125 * 500;
                    step_d <= 'd5;
                end
                'd5: begin  // 准备除法器输入
                    denom <= denom_r;
                    numer <= numer_r;
                    step_d <= 'd6;
                end    
                'd6: begin  // 获取cosθ0结果
                    cos_theta_0 <= quotient;
                    step_d <= 'd7;
                end
                'd7: begin  // 获取cosθ1结果
                    cos_theta_1 <= quotient;
                    step_d <= 'd8;
                end
                'd8: begin  // 获取cosθ2结果
                    cos_theta_2 <= quotient;
                    step_d <= 'd9;
                end
                'd9: begin  // 获取cosθ3结果
                    cos_theta_3 <= quotient;
                    step_d <= 'd10;
                end
                'd10: begin  // 获取tanθ结果（用于方形偏移）
                    tan_theta <= quotient;
                    step_d <= 'd0;
                    valid_d <= 'b1;
                end
            endcase
        end
    end
    
    // 除法器实例化
    DIV DIV (
        .clock(Clk),
        .denom(denom),
        .numer(numer),
        .quotient(quotient),
        .remain()
    );

////////////////////////////////////////// 反余弦计算（使用ROM查找表）
    // 反余弦ROM实例化
    Acos_Rom Acos_Rom(
        .address(address),
        .clock(Clk),
        .q(q)
    );
    
    // 反余弦计算状态机
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            J0r2 <= 'b0;
            Theta_1 <= 'b0;
            Theta_2 <= 'b0;
            Theta_3 <= 'b0;
            cos_theta <= 'b0;
            address <= 'd0;
            step_a <= 'd0;
            valid_a <= 'b0;
        end
        else begin
            case(step_a)
                'd0: begin  // 等待启动
                    address <= address;
                    cos_theta <= cos_theta;
                    step_a <= valid_d ? 'd1 : 'd0;
                    valid_a <= 'b0;
                end
                'd1: begin  // 准备cosθ0
                    cos_theta <= (cos_theta_0 > 1000) ? 'd1000 :
                                (cos_theta_0 < -1000) ? -'d1000 : cos_theta_0;
                    step_a <= 'd2;
                end
                'd2: begin  // 查询cosθ0的反余弦
                    address <= 1000 - cos_theta;  // ROM地址映射
                    cos_theta <= (cos_theta_1 > 1000) ? 'd1000 :
                                (cos_theta_1 < -1000) ? -'d1000 : cos_theta_1;
                    step_a <= 'd3;
                end
                'd3: begin  // 查询cosθ1的反余弦
                    address <= 1000 - cos_theta;
                    cos_theta <= (cos_theta_2 > 1000) ? 'd1000 :
                                (cos_theta_2 < -1000) ? -'d1000 : cos_theta_2;
                    step_a <= 'd4;
                end
                'd4: begin  // 查询cosθ2的反余弦
                    address <= 1000 - cos_theta;
                    cos_theta <= (cos_theta_3 > 1000) ? 'd1000 :
                                (cos_theta_3 < -1000) ? -'d1000 : cos_theta_3;
                    step_a <= 'd5;
                end
                'd5: begin  // 存储θ0结果
                    J0r2 <= q;
                    address <= 1000 - cos_theta;
                    step_a <= 'd6;
                end
                'd6: begin  // 存储θ1结果
                    Theta_1 <= q;
                    step_a <= 'd7;
                end
                'd7: begin  // 存储θ2结果
                    Theta_2 <= q;
                    step_a <= 'd8;
                end
                'd8: begin  // 存储θ3结果
                    Theta_3 <= q;
                    valid_a <= 'b1;
                    step_a <= 'd0;
                end
                default: step_a <= 'd0;
            endcase
        end
    end    
        
////////////////////////////////////////// 关节角度计算
    //J0角度计算（考虑X方向符号）
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n)
            J0r <= 'b0;
        else if(valid_a_r2)
            J0r <= J0r2;  // 如果X为负，角度取反
    end
    
    // J1-J3角度计算（基于机械臂几何关系）
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            J1r <= 'b0;
            J2r <= 'b0;
            J3r <= 'b0;
        end
        else if(valid_a_r[0]) begin
            J1r <= 'd900 - Theta_1 - Theta_2;  // 900 = 90度（0.1度单位）
            J2r <= 'd1800 - Theta_3;           // 1800 = 180度
            J3r <= Theta_1 + Theta_2 + Theta_3 - 'd900;
        end
    end
    
    // 最终角度输出（应用调整值）
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            J0 <= 'b0;
            J1 <= 'b0;
            J2 <= 'b0;
            J3 <= 'b0;
        end
        else if(valid_a_r[2]) begin
            J0 <= J0r+adjust0;
            J1 <= J1r-30;   
            J2 <= J2r-50;//50
            J3 <= J3r+ $signed(adjust3);  // 应用动态调整值
        end
    end

////////////////////////////////////////// 正方形角度偏移量计算
    // 准备除法器输入（计算高宽比）
    always@(posedge Clk or negedge Rst_n) begin
        if(!Rst_n) begin
            denom_r <= 'b0;
            numer_r <= 'b0;
            signal <= 'b0;
            height <= 'b0;
            width <= 'b0;
        end
        else if(update_rac) begin  // 更新尺寸数据
            height <= height_r;
            width <= width_r;
        end
        else if(update_r) begin  // 准备高宽比计算
            if(height <= width) begin
                denom_r <= width;
                numer_r <= height * 1000;  // 放大1000倍
                signal <= 'b0;  // 正号
            end
            else begin
                denom_r <= height;
                numer_r <= width * 1000;
                signal <= 'b1;  // 负号
            end
        end
    end

    //反正切ROM实例化
    // Atan_Rom Atan_Rom(
        // .address(address_atan_rom),
        // .clock(Clk),
        // .q(q_atan_rom)
    // );

   // 反正切计算状态机
    // always@(posedge Clk or negedge Rst_n) begin
        // if(!Rst_n) begin
            // address_atan_rom <= 'd0;
            // cnt_at <= 'd0;
            // Offset_angle <= 'd0;
            // tan_theta_r <= 'b0;
        // end
        // else if(valid_d_r) begin  // 存储tanθ结果
            // if((height <= 5 && width <= 5))  // 忽略小尺寸
                // tan_theta_r <= 'b0;
            // else
                // tan_theta_r <= tan_theta;
        // end
        // else if(valid_a) begin  // 启动反正切查询
            // address_atan_rom <= 1000 - tan_theta_r;
            // cnt_at <= 'd1;
        // end
        // else if(cnt_at >= 'b1) 
        // begin  // 等待ROM输出
            // if(cnt_at == 'd5) begin  // 5周期后获取结果
                // cnt_at <= 'b0;
                // Offset_angle <= signal ? -q_atan_rom : q_atan_rom;  // 应用符号
            // end
            // else
                // cnt_at <= cnt_at + 'b1;
        // end    
    // end    
//////////////////////////////////////////
endmodule