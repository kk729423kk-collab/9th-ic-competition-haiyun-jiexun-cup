`timescale 1ns/1ns

module five_servo_control_tb;

// 参数定义
parameter CLK_PERIOD = 20;  // 50MHz时钟周期(20ns)
parameter TEST_DELAY = 100; // 测试间隔

// 输入信号
reg clk;
reg rst_n;
reg en;
reg [11:0] angle1, angle2, angle3, angle4, angle5;

// 输出信号
wire angle_error;
wire motion_done;
wire [4:0] pwm_out;

// 实例化被测模块
five_servo_control dut (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .angle1(angle1),
    .angle2(angle2),
    .angle3(angle3),
    .angle4(angle4),
    .angle5(angle5),
    .angle_error(angle_error),
    .motion_done(motion_done),
    .pwm_out(pwm_out)
);

// 时钟生成
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// 测试流程
initial begin
    // 初始化
    rst_n = 0;
    en = 0;
    angle1 = 0; angle2 = 0; angle3 = 0; angle4 = 0; angle5 = 0;
    
    // 复位
    #100;
    rst_n = 1;
    #100;
    
    // 测试场景1：正常角度范围
    $display("=== 测试场景1：正常角度范围 ===");
    test_sequence(12'd1350, 12'd900, 12'd2000, 12'd500, 12'd600);
    
    // 测试场景2：边界角度测试
    $display("=== 测试场景2：边界角度测试 ===");
    test_sequence(12'd2700, 12'd1800, 12'd2700, 12'd0, 12'd0);
    
    // 测试场景3：角度超限测试
    $display("=== 测试场景3：角度超限测试 ===");
    test_error_case(12'd3000, 12'd900, 12'd2000, 12'd500, 12'd600);
    
    // 测试场景4：随机角度测试
    $display("=== 测试场景4：随机角度测试 ===");
    repeat(5) begin
        test_random_angles();
        #TEST_DELAY;
    end
    
    // 结束仿真
    #1000;
    $display("所有测试完成");
    $finish;
end

// 测试任务：正常角度序列
task test_sequence;
    input [11:0] a1, a2, a3, a4, a5;
    begin
        $display("设置角度：%0d° %0d° %0d° %0d° %0d°", 
                 a1/10, a2/10, a3/10, a4/10, a5/10);
        
        angle1 = a1; angle2 = a2; angle3 = a3; angle4 = a4; angle5 = a5;
        en = 1;
        
        wait(motion_done);
        $display("运动完成 @ %t ns", $time);
        en = 0;
        #TEST_DELAY;
    end
endtask

// 测试任务：错误角度测试
task test_error_case;
    input [11:0] a1, a2, a3, a4, a5;
    begin
        $display("设置超限角度：%0d° %0d° %0d° %0d° %0d°", 
                 a1/10, a2/10, a3/10, a4/10, a5/10);
        
        angle1 = a1; angle2 = a2; angle3 = a3; angle4 = a4; angle5 = a5;
        en = 1;
        
        #100;
        if(angle_error)
            $display("检测到角度超限错误（符合预期）");
        else
            $display("错误：未检测到角度超限");
        
        en = 0;
        #TEST_DELAY;
    end
endtask

// 测试任务：随机角度生成
task test_random_angles;
    begin
        angle1 = $urandom_range(0, 2700);  // 0-270.0°
        angle2 = $urandom_range(0, 1800);  // 0-180.0°
        angle3 = $urandom_range(0, 2700);
        angle4 = $urandom_range(0, 2700);
        angle5 = $urandom_range(0, 1800);
        en = 1;
        
        $display("随机角度：%0d° %0d° %0d° %0d° %0d°", 
                 angle1/10, angle2/10, angle3/10, angle4/10, angle5/10);
        
        wait(motion_done);
        $display("随机测试完成 @ %t ns", $time);
        en = 0;
    end
endtask

// PWM波形监测
always @(posedge clk) begin
    if(en) begin
        $display("PWM状态: S1=%b S2=%b S3=%b S4=%b S5=%b",
                 pwm_out[0], pwm_out[1], pwm_out[2], pwm_out[3], pwm_out[4]);
    end
end

// 波形记录
initial begin
    $dumpfile("five_servo_control.vcd");
    $dumpvars(0, five_servo_control_tb);
end

endmodule