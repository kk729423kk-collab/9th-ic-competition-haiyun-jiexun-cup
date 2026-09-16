`timescale 1ns/1ns

module five_servo_control 
#(
    parameter PWM_PERIOD  = 1_000_000,   // 20ms@50MHz
    parameter BASE_PULSE  = 25_000,      // 0.5ms基数
    parameter INTERNAL_SPEED = 200_000       // 建议值：100-1000
)
(
    input         clk,
    input         rst_n,
    input         en,
    
    // 各舵机目标角度输入
    input  [11:0] angle1, angle2, angle3, angle4, angle5,
    
    // 状态输出
    output        angle_error,
    output        motion_done,
    
    // 独立PWM输出（不再使用数组）
    output        pwm_servo1,  // 舵机1
    output        pwm_servo2,  // 舵机2
    output        pwm_servo3,  // 舵机3
    output        pwm_servo4,  // 舵机4
    output        pwm_servo5   // 舵机5
);

// 参数定义
localparam ANGLE_MAX_270 = 2700;
localparam ANGLE_MAX_180 = 1800;
localparam SCALE_270 = 37;
localparam SCALE_180 = 55;
    
localparam SPEED0 = INTERNAL_SPEED/3;  // 100,000
localparam SPEED1 = INTERNAL_SPEED/3;  // ~66,666
localparam SPEED2 = INTERNAL_SPEED/3;  // ~66,666
localparam SPEED3 = INTERNAL_SPEED/3;  // ~66,666
localparam SPEED4 = INTERNAL_SPEED/4;  // 50,000

// localparam  SPEED0   =100_000;
// localparam  SPEED1   =100_000;
// localparam  SPEED2   =100_000;
// localparam  SPEED3   =100_000;
// localparam  SPEED4   =100_000;

// 中间信号
wire err1, err2, err3, err4, err5;
wire done1, done2, done3, done4, done5;

// 实例化5个独立舵机单元
servo_unit  
#
(
    .INIT_ANGLE(1220),
    .PWM_PERIOD (PWM_PERIOD),   // 20ms@50MHz
    .BASE_PULSE  (BASE_PULSE),      // 0.5ms基数
    .INTERNAL_SPEED (SPEED0)      
        
)
servo1
(
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .target_angle(angle1),
    .angle_max(ANGLE_MAX_270),
    .scale_factor(SCALE_270),
    .angle_error(err1),
    .motion_done(done1),
    .pwm_out(pwm_servo1)
);

servo_unit 
#
(
    .INIT_ANGLE(850),
    .PWM_PERIOD (PWM_PERIOD),   // 20ms@50MHz
    .BASE_PULSE  (BASE_PULSE),      // 0.5ms基数
    .INTERNAL_SPEED (SPEED1)      // 建议值：100-1000
)
servo2
(
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .target_angle(angle2),
    .angle_max(ANGLE_MAX_180),
    .scale_factor(SCALE_180),
    .angle_error(err2),
    .motion_done(done2),
    .pwm_out(pwm_servo2)
);

servo_unit #
(
    .INIT_ANGLE(1350),
    .PWM_PERIOD (PWM_PERIOD),   // 20ms@50MHz
    .BASE_PULSE  (BASE_PULSE),      // 0.5ms基数
    .INTERNAL_SPEED (SPEED2)      // 建议值：100-1000
)
servo3 
(
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .target_angle(angle3),
    .angle_max(ANGLE_MAX_270),
    .scale_factor(SCALE_270),
    .angle_error(err3),
    .motion_done(done3),
    .pwm_out(pwm_servo3)
);

servo_unit #
(
    .INIT_ANGLE(450),
    .PWM_PERIOD (PWM_PERIOD),   // 20ms@50MHz
    .BASE_PULSE  (BASE_PULSE),      // 0.5ms基数
    .INTERNAL_SPEED (SPEED3)      // 建议值：100-1000
)
servo4
 (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .target_angle(angle4),
    .angle_max(ANGLE_MAX_180),
    .scale_factor(SCALE_180),
    .angle_error(err4),
    .motion_done(done4),
    .pwm_out(pwm_servo4)
);

servo_unit #
(
    .INIT_ANGLE(2700),
    .PWM_PERIOD (PWM_PERIOD),   // 20ms@50MHz
    .BASE_PULSE  (BASE_PULSE),      // 0.5ms基数
    .INTERNAL_SPEED (SPEED4)      // 建议值：100-1000
)
servo5
 (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .target_angle(angle5),
    .angle_max(ANGLE_MAX_270),
    .scale_factor(SCALE_270),
    .angle_error(err5),
    .motion_done(done5),
    .pwm_out(pwm_servo5)
);

// 全局状态输出
assign angle_error = err1 | err2 | err3 | err4 | err5;
assign motion_done = done1 & done2 & done3 & done4 & done5;

endmodule