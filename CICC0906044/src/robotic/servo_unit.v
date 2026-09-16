`timescale 1ns/1ns

module servo_unit 
#(
    parameter INIT_ANGLE  = 1350,        // 初始角度(135.0°)
    parameter PWM_PERIOD  = 1_000_000,   // 20ms@50MHz
    parameter BASE_PULSE  = 25_000,      // 0.5ms基数
    parameter INTERNAL_SPEED = 10_000       // 建议值：100-1000
)
(
    input         clk,
    input         rst_n,
    input         en,
    input  [11:0] target_angle,  // 0.1°精度
    input  [11:0] angle_max,     // 最大角度限制
    input  [15:0] scale_factor,  // 脉宽缩放系数
    output        angle_error,
    output        motion_done,
    output        pwm_out
);

// 寄存器定义
reg [19:0] pwm_cnt;
reg [23:0] pulse_width;
reg [11:0] current_angle;
reg [17:0] speed_cnt;
reg pwm_out_reg;
//reg done_reg;

// 角度校验
assign angle_error = en & ((target_angle > angle_max) || (target_angle < 0));

// 运动完成判断（添加寄存器输出）
assign motion_done = (current_angle == target_angle);

// 运动控制
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        speed_cnt <= 0;
        current_angle <= INIT_ANGLE;
    end
    else if (en && !angle_error) begin  // 添加en使能控制
        if (current_angle == target_angle) begin
            speed_cnt <= 0;
        end
        else begin
            if (speed_cnt == INTERNAL_SPEED) begin
                speed_cnt <= 0;
                current_angle <= (current_angle < target_angle) ? 
                    current_angle + 1 : current_angle - 1;
            end
            else begin
                speed_cnt <= speed_cnt + 1;
            end
        end
    end
end

// PWM生成（保持不变）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pwm_cnt <= 0;
        pulse_width <= 75_000;  // 中位脉宽
    end 
    else begin
        pwm_cnt <= (pwm_cnt == PWM_PERIOD-1) ? 0 : pwm_cnt + 1;
        pulse_width <= BASE_PULSE + (current_angle * scale_factor);
    end
end

// 输出寄存器
always @(posedge clk) begin
    pwm_out_reg <= (pwm_cnt < pulse_width);
end
assign pwm_out = pwm_out_reg;

endmodule