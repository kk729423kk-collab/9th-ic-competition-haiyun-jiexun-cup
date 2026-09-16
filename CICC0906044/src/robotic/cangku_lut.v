module cangku_lut (
    input      [4:0] cangku_addr,     // 5-bit address (0-23)
    input      sys_clk,               // 系统时钟（实际未使用）
    output wire signed [11:0] cangku_lut_J0,  // 11-bit 有符号输出
    output wire signed [11:0] cangku_lut_J1,
    output wire signed [11:0] cangku_lut_J2,
    output wire signed [11:0] cangku_lut_J3
);

wire [47:0] q;

// 建议位序（高位在前）
assign cangku_lut_J3 = q[11:0];
assign cangku_lut_J2 = q[23:12];
assign cangku_lut_J1 = q[35:24];
assign cangku_lut_J0 = q[47:36];

// IP核实例化
cangku_pos_rom cangku_pos_rom_inst (
    .address (cangku_addr),
    .clock   (sys_clk),
    .q       (q)
);

endmodule