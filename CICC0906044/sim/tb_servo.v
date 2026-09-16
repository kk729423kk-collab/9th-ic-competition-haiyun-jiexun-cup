`timescale 1ns/1ns

module tb_servo();

// 时钟和复位信号
reg clk = 0;
reg rst_n = 0;
reg en = 0;

// 输入信号
reg [11:0] target_angle = 1350;  // 初始135.0°
reg [11:0] angle_max = 2700;     // 最大270.0°
reg [15:0] scale_factor = 74;    // 缩放系数

// 输出信号
wire angle_error;
wire motion_done;
wire pwm_out;

// 生成50MHz时钟（周期20ns）
always #10 clk = ~clk;
// 实例化被测模块（覆盖仿真参数）
servo_unit #(
    .PWM_PERIOD(20_000),    // 20us代替20ms（加速1000倍）
    .BASE_PULSE(500),       // 500ns代替0.5ms
    .INTERNAL_SPEED(10)   // 加速运动控制
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .target_angle(target_angle),
    .angle_max(angle_max),
    .scale_factor(scale_factor),
    .angle_error(angle_error),
    .motion_done(motion_done),
    .pwm_out(pwm_out)
);

//

// 主测试流程
initial begin
    
    rst_n =0;
    // 复位（100ns后释放）
    #100 rst_n = 1;
    
    // 测试1：验证初始状态
    #100
    
    // 测试2：运动到180度（+45度）
    en = 1;
    target_angle = 1800;
    #400000;
   

    // 测试3：返回135度（-45度）
    target_angle = 1350;
    #400000;
    
     target_angle = 450;
    #400000;
    // 测试4：超限检测
    target_angle = 3000;  // 超过270度限制
    #100;

    
  
end


endmodule