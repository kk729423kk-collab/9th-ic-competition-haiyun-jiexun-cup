module qibeng_ctrl
(
    input sys_clk,
    input sys_rst_n,
    input xi_flag,
    input fang_flag,
    output qibeng_tx
);
wire [7:0] tx_buf [0:20];
// 将字符串 "#255P2500T0000!" 拆解为 ASCII 码赋值
assign tx_buf[0]  = "#";  // 8'h23
assign tx_buf[1]  = "2";  // 8'h32
assign tx_buf[2]  = "5";  // 8'h35
assign tx_buf[3]  = "5";  // 8'h35
assign tx_buf[4]  = "P";  // 8'h50
assign tx_buf[5]  = (xi_flag==1'b1)?"2":((fang_flag==1'b1)?"1":tx_buf[5]);  // 8'h32
assign tx_buf[6]  = "5";  // 8'h35
assign tx_buf[7]  = "0";  // 8'h30
assign tx_buf[8]  = "0";  // 8'h30
assign tx_buf[9]  = "T";  // 8'h54
assign tx_buf[10] = "0";  // 8'h30
assign tx_buf[11] = "0";  // 8'h30
assign tx_buf[12] = "0";  // 8'h30
assign tx_buf[13] = "0";  // 8'h30
assign tx_buf[14] = "!";  // 8'h21
reg tx_flag;
wire tx_done;
//实例化修改后的模块
tx_pro
#(
    .UART_BPS(115200),
    .CLK_FREQ(50_000_000)
)
uart_tx_inst (
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .tx_flag(xi_flag||fang_flag),
    .data_len(15), // 发送5字节
    .data_in(tx_buf), // 数据内容
    .use_header(1'b0),    // 新增：是否使用包头(1启用)
    .use_trailer(1'b0),   // 新增：是否使用包尾(1启用)
    .tx(qibeng_tx),
    .tx_complete(tx_done)
);



endmodule
