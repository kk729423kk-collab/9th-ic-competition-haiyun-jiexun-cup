`timescale 1ns/1ns

module tb_block_ctrl;

// 时钟和复位
reg clk;
reg reset_n;

// 输入信号
reg sys_start;
reg arm_done;
reg vision_ack;

// 输出信号
wire [4:0] vision_pos;
wire [1:0] req_color;
wire [1:0] req_shape;
wire [1:0] req_angle;
wire req_vision;
wire sys_finish;

// 实例化被测模块
block_controller dut (
    .clk(clk),
    .reset_n(reset_n),
    .sys_start(sys_start),
    .vision_ack(vision_ack),
    .vision_pos(vision_pos),
    .req_color(req_color),
    .req_shape(req_shape),
    .req_angle(req_angle),
    .req_vision(req_vision),
    .arm_done(arm_done),
    .sys_finish(sys_finish)
);

// 生成10MHz时钟 (周期100ns)
always #50 clk = ~clk;

// 主测试流程
initial begin
    // 初始化
    clk = 0;
    reset_n = 0;
    sys_start = 0;
    arm_done = 0;
    vision_ack = 0;
    
    // 复位（2个时钟周期）
    #100 reset_n = 1;
    
    // 启动系统
    #100 sys_start = 1;
  //  #100 sys_start = 0;
    
    // 等待并响应视觉请求
    // while(1) 
    // begin
        // 等待视觉请求
        wait(req_vision == 1);
        $display("[%0t] 视觉请求位置：%d", $time, vision_pos);
        
        // 模拟视觉处理时间（600ns）
        #600 vision_ack = 1;
        #100 vision_ack = 0;
        
        // 模拟机械臂操作时间（1us）
        #800 arm_done = 1;
        #100 arm_done = 0;
        
        // 检查是否完成
        
   //end
end

endmodule