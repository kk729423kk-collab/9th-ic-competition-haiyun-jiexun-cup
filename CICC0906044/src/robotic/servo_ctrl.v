`timescale 1ns/1ns

module servo_ctrl 
#
(
    parameter PWM_PERIOD  = 1_000_000,   // 20ms@50MHz
    parameter BASE_PULSE  = 25_000,      // 0.5ms基数
    parameter INTERNAL_SPEED = 10_000       // 建议值：100-1000
)
(
    input         clk,
    input         rst_n,
    input         en,
    
    // 各舵机角度变化值（有符号，0.1°精度）
    input  signed [11:0] delta_angle1,  // 舵机1 (270°范围)
    input  signed [11:0] delta_angle2,  // 舵机2 (180°范围)
    input  signed [11:0] delta_angle3,  // 舵机3 (270°范围)
    input  signed [11:0] delta_angle4,  // 舵机4 (270°范围)
    input  signed [11:0] delta_angle5,  // 舵机5 (180°范围)
    
    // 状态输出
    output        angle_error,
    output        motion_done,
    
    // PWM输出
    output        pwm_servo1,
    output        pwm_servo2,
    output        pwm_servo3,
    output        pwm_servo4,
    output        pwm_servo5
);

// 基准角度定义（0.1°精度）
localparam [11:0] BASE_ANGLE_0 = 12'd1220;  // 舵机1初始135.0°
localparam [11:0] BASE_ANGLE_1 = 12'd850;   // 舵机2初始90.0°
localparam [11:0] BASE_ANGLE_2 = 12'd1350;  // 舵机3初始135.0°
localparam [11:0] BASE_ANGLE_3 = 12'd450;  // 舵机4初始135.0°
localparam [11:0] BASE_ANGLE_4 = 12'd2700;   // 舵机5初始90.0°

// 目标角度计算（关键修正：加上delta_angle）
wire signed [12:0] target_angle1 = BASE_ANGLE_0 + delta_angle1;
wire signed [12:0] target_angle2 = BASE_ANGLE_1 + delta_angle2;
wire signed [12:0] target_angle3 = BASE_ANGLE_2 + delta_angle3;
wire signed [12:0] target_angle4 = BASE_ANGLE_3 + delta_angle4;
wire signed [12:0] target_angle5 = BASE_ANGLE_4 + delta_angle5;
// 实例化舵机控制器
five_servo_control 
#
(
    .PWM_PERIOD (PWM_PERIOD),   // 20ms@50MHz
    .BASE_PULSE  (BASE_PULSE),      // 0.5ms基数
    .INTERNAL_SPEED (INTERNAL_SPEED)      // 建议值：100-1000
)
u_five_servo 
(
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .angle1(target_angle1[11:0]), // 取低12位
    .angle2(target_angle2[11:0]),
    .angle3(target_angle3[11:0]),
    .angle4(target_angle4[11:0]),
    .angle5(target_angle5[11:0]),
    .angle_error(angle_error),
    .motion_done(motion_done),
    .pwm_servo1(pwm_servo1),
    .pwm_servo2(pwm_servo2),
    .pwm_servo3(pwm_servo3),
    .pwm_servo4(pwm_servo4),
    .pwm_servo5(pwm_servo5)
);


endmodule