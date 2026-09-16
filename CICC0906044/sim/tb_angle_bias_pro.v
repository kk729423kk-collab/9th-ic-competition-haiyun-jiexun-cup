`timescale 1ns/1ns

module tb_angle_bias_pro;

// 输入信号
reg clk;
reg rst_n;
reg [1:0] shape;
reg [39:0] border;
reg [9:0] first_x;
reg [9:0] last_x;

// 输出信号
wire [1:0] angle_mode;
wire [1:0] shape_state;
wire [9:0] a;
wire [9:0] b;
wire data_valid;

// 实例化被测模块
ShapeAngleProcessor uut (
    .clk(clk),
    .rst_n(rst_n),
    .shape(shape),
    .border(border),
    .first_x(first_x),
    .last_x(last_x),
    .angle_mode(angle_mode),
    .shape_state(shape_state),
    .a(a),
    .b(b),
    .data_valid(data_valid)
);

// 时钟生成（周期=10ns）
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// 测试用例
initial begin
    // 初始化
    rst_n = 0;
    shape = 0;
    border = 0;
    first_x = 0;
    last_x = 0;
    #20;
    
    // 释放复位
    rst_n = 1;
    
    // 测试用例1：标准正方形
    #10;
    shape = 2'b11;  // 正方形
    border = {10'd0, 10'd100, 10'd100, 10'd0};  // left=0, top=100, right=100, bottom=0
    first_x = 10'd0;
    last_x = 10'd100;
    #20;
    
    // 测试用例2：斜边正方形（对角线）
    #10;
    first_x = 10'd20;
    last_x = 10'd80;
    #20;
    
    // 测试用例3：宽矩形三角形（左下直角）
    #10;
    shape = 2'b00;  // 三角形
    border = {10'd0, 10'd50, 10'd100, 10'd0};  // left=0, top=50, right=100, bottom=0
    first_x = 10'd0;
    last_x = 10'd100;
    #20;
    
    // 测试用例4：高矩形三角形（左上直角）
    #10;
    border = {10'd0, 10'd100, 10'd50, 10'd0};  // left=0, top=100, right=50, bottom=0
    first_x = 10'd50;
    last_x = 10'd0;
    #20;
    
    // 测试用例5：高矩形三角形（右下直角）
    #10;
    border = {10'd0, 10'd100, 10'd50, 10'd0};  // left=0, top=100, right=50, bottom=0
    first_x = 10'd50;
    last_x = 10'd0;
    #20;
    
    // 结束仿真
    #100;
end

// 监控输出
initial begin
    $monitor("At time %t: shape=%b, state=%b, angle_mode=%b, a=%d, b=%d, valid=%b",
             $time, shape, shape_state, angle_mode, a, b, data_valid);
end

endmodule