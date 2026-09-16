`timescale 1ns/1ns

module jixiebi_top 
#(
    parameter CLK_FREQ = 50_000_000,  // 系统时钟频率50MHz
    parameter PWM_PERIOD  = 1_000_000,   // PWM周期=20ms(50Hz)
    parameter BASE_PULSE  = 25_000,      // 0.5ms基准脉宽
    parameter INTERNAL_SPEED = 200_000   // 舵机运动速度控制
)
(
    // 系统信号
    input clk,                    // 50MHz系统时钟
    input rst_n,                  // 低电平复位
    
    // 目标位置输入
    input signed [15:0] target_x, // 目标X坐标（有符号数）
    input signed [15:0] target_y, // 目标Y坐标（有符号数）
    input target_valid,           // 目标坐标有效信号
    
    // 仓库位置选择
    input [4:0] target_cangku_addr,    // 5位线性地址 (0-23)
    input [1:0] target_angle,
    
    // 执行机构控制
    output reg pump_ctrl,             // 气泵控制信号
    output pwm_servo1,            // 舵机1 PWM
    output pwm_servo2,            // 舵机2 PWM 
    output pwm_servo3,            // 舵机3 PWM
    output pwm_servo4,            // 舵机4 PWM
    output pwm_servo5,            // 舵机5 PWM
    
    // 状态输出
    output reg finish,            // 任务完成标志
    output reg [4:0] state         // 当前状态机状态（调试用）
);

// ==============================================
// 系统参数定义
// ==============================================

// 机械臂高度定义
localparam signed [14:0] Z_HIGH   = 15'sd40;  // 高位安全高度（有符号）
localparam signed [14:0] Z_MIDDLE = 15'sd20;  // 中间过渡高度（新增）
localparam signed [14:0] Z_LOW    = -15'sd5;   // 低位抓取高度（有符号）

// 状态机状态定义
localparam IDLE            = 5'd0;   // 空闲状态
localparam CALC_IK_PREP    = 5'd1;   // 计算准备位逆解
localparam MOVE_TO_PREP    = 5'd2;   // 移动到准备位
localparam PREP_DELAY      = 5'd3;   // 准备位停留3秒
localparam CALC_IK_MID     = 5'd4;  // 计算中间高度逆解（新增）
localparam MOVE_TO_MID     = 5'd5;  // 移动到中间高度（新增）
localparam MID_DELAY       = 5'd6;  // 中间高度停留1秒
localparam CALC_IK_PICK    = 5'd7;   // 计算抓取位逆解
localparam MOVE_TO_PICK    = 5'd8;   // 移动到抓取位同时开启气泵
localparam PUMP_ON_HOLD    = 5'd9;   // 气泵保持3秒
localparam CALC_IK_LIFT    = 5'd10;   // 计算抬升逆解
localparam LIFT_UP         = 5'd11;   // 抬升物体
localparam MOVE_TO_STORE   = 5'd12;  // 移动到仓库
localparam PRE_PUMP_OFF_HOLD = 5'd13;  // 仓库位置停留3秒
localparam PUMP_OFF        = 5'd14;  // 关闭气泵
localparam PUMP_OFF_HOLD   =5'd15;
localparam DONE            = 5'd16;  // 任务完成
localparam DONE_HOLD       = 5'd17;  // 任务完成

// 计时器参数
localparam PREP_STAY_TIME  = CLK_FREQ * 1; // 准备位停留3秒
localparam MID_STAY_TIME   = CLK_FREQ * 1; // 中间高度停留1秒（新增）
localparam PUMP_ON_HOLD_TIME  = CLK_FREQ * 2; // 气泵保持3秒
localparam PRE_PUMP_OFF_HOLD_TIME = CLK_FREQ *1 ; // 仓库停留3秒
localparam PUMP_OFF_HOLD_TIME = CLK_FREQ * 1; // 仓库停留3秒


// ==============================================
// 内部信号定义
// ==============================================
reg [27:0] timer;                  // 通用计时器
reg update_ik;                    // 逆解计算触发
reg signed [15:0] X, Y, Z;        // 当前目标坐标
wire signed [11:0] delta_J0, delta_J1, delta_J2, delta_J3; // 逆解结果
wire ik_valid;                    // 逆解完成标志

// 仓库位置预设角度
wire signed [11:0] cangku_delta_J0, cangku_delta_J1, 
                   cangku_delta_J2, cangku_delta_J3;

// 舵机控制接口
wire motion_done;                 // 运动完成标志
wire angle_error;                 // 角度错误标志

// 位置存储寄存器
reg [4:0]  current_cangku_addr;   // 5位线性地址 (0-23)
reg signed [15:0] current_target_x;
reg signed [15:0] current_target_y;


// 当前舵机角度
reg signed [11:0] current_delta_0, current_delta_1, 
                  current_delta_2, current_delta_3, current_delta_4;

// J4角度计算专用信号
reg signed [11:0] target_j0;      // 目标位置的J0角度
reg signed [11:0] store_j0;       // 仓库位置的J0角度
reg signed [11:0] j4_angle_final;  // 最终修正的J4角度
reg vld_dly1;
reg vld_dly2;
// ==============================================
// 模块实例化
// ==============================================

// 逆运动学求解模块
Inverse_kinematics_ak u_ik (
    .Clk(clk),
    .Rst_n(rst_n),
    .update(update_ik),
    .X(X),
    .Y(Y),
    .Z(Z),
    .height_r(8'd0),
    .width_r(8'd0),
    .update_rac(1'b0),
    .adjust(7'd0),
    .J0(delta_J0),
    .J1(delta_J1),
    .J2(delta_J2),
    .J3(delta_J3),
    .Offset_angle(),
    .valid(ik_valid)
);

// 仓库位置查找表
cangku_lut u_cangku_lut (
    .cangku_addr(current_cangku_addr),
    .sys_clk(clk),  
    .cangku_lut_J0(cangku_delta_J0),
    .cangku_lut_J1(cangku_delta_J1),
    .cangku_lut_J2(cangku_delta_J2),
    .cangku_lut_J3(cangku_delta_J3)
);

// 五路舵机控制模块
servo_ctrl #(
    .PWM_PERIOD(PWM_PERIOD),
    .BASE_PULSE(BASE_PULSE),
    .INTERNAL_SPEED(INTERNAL_SPEED)
) u_servo_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .en(1'b1),
    .delta_angle1(current_delta_0),
    .delta_angle2(current_delta_1),
    .delta_angle3(current_delta_2),
    .delta_angle4(current_delta_3),
    .delta_angle5(current_delta_4),
    .angle_error(angle_error),
    .motion_done(motion_done),
    .pwm_servo1(pwm_servo1),
    .pwm_servo2(pwm_servo2),
    .pwm_servo3(pwm_servo3),
    .pwm_servo4(pwm_servo4),
    .pwm_servo5(pwm_servo5)
);


// ==============================================
// J4角度计算组合逻辑（优化版）
// ==============================================
localparam ANGLE_180 = 12'd1800;  // 180度对应值（12位有符号）
localparam ANGLE_360 = 12'd3600;  // 360度对应值

always @(*) begin
    j4_angle_final = store_j0-target_j0;    
end
reg [2:0] hold_cnt;
// ==============================================
// 主状态机（完整实现）
// ==============================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        finish <= 1'b0;
        update_ik <= 1'b0;
        current_target_x <= 16'd0;
        current_target_y <= 16'd0;
        current_cangku_addr <= 5'd0;
        timer <= 28'd0;

        current_delta_0 <= 12'd0;
        current_delta_1 <= 12'd0;
        current_delta_2 <= 12'd0;
        current_delta_3 <= 12'd0;
        current_delta_4 <= 12'd0;
        target_j0 <= 12'd0;
        store_j0 <= 12'd0;
         vld_dly1<=1'b0;
         vld_dly2<=1'b0;
         pump_ctrl <= 1'b0;       // 准备开启气泵
    end else begin
         vld_dly1<=target_valid;
         vld_dly2<=vld_dly1;
        case (state)
            IDLE: begin
                timer <= 28'd0;
      
                target_j0 <= 12'd0;
                store_j0 <= 12'd0;
        
                hold_cnt<=3'd0;
                finish<=1'b0;
                if (vld_dly2) begin
                    current_target_x <= target_x;
                    current_target_y <= target_y;
                    current_cangku_addr <= target_cangku_addr;
                    state <= CALC_IK_PREP;
                    X <= target_x;
                    Y <= target_y;
                    Z <= Z_HIGH;
                    update_ik <= 1'b1;
                end
            end
            
            CALC_IK_PREP: begin
                update_ik <= 1'b0;
                if (ik_valid) begin
                    current_delta_0 <= delta_J0;
                    current_delta_1 <= delta_J1;
                    current_delta_2 <= delta_J2;
                    current_delta_3 <= delta_J3;
                    state <= MOVE_TO_PREP;
                end
            end
            
            MOVE_TO_PREP: begin
                if (motion_done) begin
                    state <= PREP_DELAY;
                    timer <= 28'd0;
                end
            end
            
            PREP_DELAY: begin
                if (timer < PREP_STAY_TIME) begin
                    timer <= timer + 1'b1;
                end else begin
                    state <= CALC_IK_MID;  // 改为先计算中间高度
                    X <= current_target_x;
                    Y <= current_target_y;
                    Z <= Z_MIDDLE;         // 中间高度
                    update_ik <= 1'b1;
                end
            end
            
            CALC_IK_MID: begin
                update_ik <= 1'b0;
                if (ik_valid) begin
                    current_delta_0 <= delta_J0;
                    current_delta_1 <= delta_J1;
                    current_delta_2 <= delta_J2;
                    current_delta_3 <= delta_J3;
                    state <= MOVE_TO_MID;
                end
            end
            
            MOVE_TO_MID: begin
                if (motion_done) begin
                    state <= MID_DELAY;
                    timer <= 28'd0;
                end
            end
            
            MID_DELAY: begin
                if (timer < MID_STAY_TIME) begin
                    timer <= timer + 1;
                end else begin
                    state <= CALC_IK_PICK;
                    X <= current_target_x;
                    Y <= current_target_y;
                    Z <= Z_LOW;
                    pump_ctrl <= 1'b1;       // 准备开启气泵
                    update_ik <= 1'b1;
                end
            end
            
            CALC_IK_PICK: begin
                update_ik <= 1'b0;
                if (ik_valid) begin
                    target_j0 <= delta_J0;  // 记录目标J0角度
                    store_j0 <= cangku_delta_J0;  // 记录仓库J0角度
                    current_delta_0 <= delta_J0;
                    current_delta_1 <= delta_J1;
                    current_delta_2 <= delta_J2;
                    current_delta_3 <= delta_J3;
                    state <= MOVE_TO_PICK;
                end
            end
            
            MOVE_TO_PICK: begin
                if (motion_done) begin
                    state <= PUMP_ON_HOLD;
                    timer <= 28'd0;
                end
            end
            PUMP_ON_HOLD: begin
                if (timer < PUMP_ON_HOLD_TIME) begin
                    timer <= timer + 1;
                end else begin
                    state <= CALC_IK_LIFT;
                    X <= current_target_x;
                    Y <= current_target_y;
                    Z <= Z_HIGH+20;
                    update_ik <= 1'b1;
                end
            end
            
            CALC_IK_LIFT: begin
                update_ik <= 1'b0;
                if (ik_valid) begin
                    current_delta_0 <= delta_J0;
                    current_delta_1 <= delta_J1;
                    current_delta_2 <= delta_J2;
                    current_delta_3 <= delta_J3;
                    state <= LIFT_UP;
                end
            end
            
            LIFT_UP: begin
                if (motion_done) begin
                    state <= MOVE_TO_STORE;
                    // 保持其他关节角度不变
                    current_delta_0 <= cangku_delta_J0;
                    current_delta_1 <= cangku_delta_J1;
                    current_delta_2 <= cangku_delta_J2;
                    current_delta_3 <= cangku_delta_J3;
                    current_delta_4 <= j4_angle_final;
                end
            end
            
            MOVE_TO_STORE: begin
                if (motion_done) begin
                    state <= PRE_PUMP_OFF_HOLD;
                    timer <= 28'd0;
                end
            end
            
            PRE_PUMP_OFF_HOLD: begin
                if (timer < PRE_PUMP_OFF_HOLD_TIME) begin
                    timer <= timer + 1;
                end else begin
                    state <= PUMP_OFF;
                    pump_ctrl <= 1'b0;
                end
            end
            
            PUMP_OFF: begin
                state<=PUMP_OFF_HOLD;
                timer <= 28'd0;
            end
            PUMP_OFF_HOLD:begin
                if(timer < PUMP_OFF_HOLD_TIME) begin
                    timer<=timer +1;
                end
                else begin
                    state<=DONE;
                    current_delta_4<=0;
                end
            end
            DONE: begin
                if(motion_done)
                    begin
                        state<=DONE_HOLD;
                        finish<=1'b1;
                    end 
            end
            DONE_HOLD: begin
                if(hold_cnt<3'd4)
                    hold_cnt<=hold_cnt+1'b1;
                else state <= IDLE;
            end
            //state <= IDLE;
            default: state <= IDLE;
        endcase
    end
end

endmodule