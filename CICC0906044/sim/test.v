`timescale 1ns/1ps

module test();

// 生成时钟信号
reg sys_clk;
initial begin
    sys_clk = 0;
    forever #5 sys_clk = ~sys_clk; // 100MHz时钟
end

// 测试信号
reg [4:0] cangku_addr;
wire signed [11:0] J0, J1, J2, J3;

// 实例化被测模块
cangku_lut dut (
    .cangku_addr(cangku_addr),
    .sys_clk(sys_clk),
    .cangku_lut_J0(J0),
    .cangku_lut_J1(J1),
    .cangku_lut_J2(J2),
    .cangku_lut_J3(J3)
);

// 测试流程
initial begin
    // 初始化
    cangku_addr = 0;
    
    // 遍历所有地址 (0-23)
    repeat(24) begin
        #10; // 等待时钟稳定
        $display("Addr=%2d -> J0=%5d, J1=%5d, J2=%5d, J3=%5d", 
                cangku_addr, J0, J1, J2, J3);
        cangku_addr = cangku_addr + 1;
    end
    
end

endmodule