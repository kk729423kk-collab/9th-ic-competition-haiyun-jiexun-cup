module key_scan (
    input   wire    sys_clk     ,   // 系统时钟 50MHz
    input   wire    sys_rst_n   ,   // 全局复位
    input   wire    key_in1     ,   // 按键输入信号 1
    input   wire    key_in2     ,   // 按键输入信号 2

    output  reg     key_flag1   ,   // 按键 1 有效标志位
    output  reg     key_flag2       // 按键 2 有效标志位
);

    // 参数定义
    parameter CNT_MAX = 20'd999_999; // 计数器计数最大值（20ms）
    parameter KEY_NUM = 2;           // 按键数量

    // 寄存器定义
    reg [19:0] cnt_20ms [0:KEY_NUM-1]; // 按键的 20ms 计数器数组
    reg [KEY_NUM-1:0] key_flag;        // 按键有效标志位数组

    // 按键计数器和标志位逻辑
    genvar i;
    generate
        for (i = 0; i < KEY_NUM; i = i + 1) begin : KEY_SCAN_LOGIC
            // 按键的计数器逻辑
            always @(posedge sys_clk or negedge sys_rst_n) begin
                if (!sys_rst_n)
                    cnt_20ms[i] <= 20'b0; // 复位时清零计数器
                else if ((i == 0 && key_in1 == 1'b1) || (i == 1 && key_in2 == 1'b1))
                    cnt_20ms[i] <= 20'b0; // 按键松开时清零计数器
                else if (cnt_20ms[i] == CNT_MAX && ((i == 0 && key_in1 == 1'b0) || (i == 1 && key_in2 == 1'b0)))
                    cnt_20ms[i] <= cnt_20ms[i]; // 计数满时保持
                else
                    cnt_20ms[i] <= cnt_20ms[i] + 1'b1; // 计数器递增
            end

            // 按键的有效标志位逻辑
            always @(posedge sys_clk or negedge sys_rst_n) begin
                if (!sys_rst_n)
                    key_flag[i] <= 1'b0; // 复位时清零标志位
                else if (cnt_20ms[i] == CNT_MAX - 1'b1)
                    key_flag[i] <= 1'b1; // 计数满时拉高标志位
                else
                    key_flag[i] <= 1'b0; // 其他情况清零标志位
            end
        end
    endgenerate

    // 将标志位数组赋值给单独的输出信号
    assign key_flag1 = key_flag[0];
    assign key_flag2 = key_flag[1];

endmodule    