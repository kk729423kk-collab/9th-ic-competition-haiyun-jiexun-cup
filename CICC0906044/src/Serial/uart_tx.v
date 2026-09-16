`timescale 1ns / 1ps

module uart_tx #(
    parameter UART_BPS = 'd9600,        // 串口波特率
    parameter CLK_FREQ = 'd50_000_000   // 时钟频率
)(
    input        sys_clk,               // 系统时钟
    input        sys_rst_n,             // 系统复位
    input  [7:0] pi_data,               // 并行数据输入
    input        pi_flag,               // 并行数据输入标志
    output reg   tx,                    // 串行数据输出
    output       tx_done                // 发送完成标志
);

// 计算分频系数
localparam BPS_CNT = CLK_FREQ / UART_BPS;

// 状态定义
localparam IDLE  = 2'b00;  // 空闲状态
localparam START = 2'b01;  // 发送起始位
localparam SEND  = 2'b10;  // 发送数据位
localparam STOP  = 2'b11;  // 发送停止位

reg [1:0] state;           // 当前状态
reg [15:0] bps_cnt;        // 波特率计数器
reg [3:0] bit_cnt;         // 发送位数计数器
reg [7:0] tx_data;         // 发送数据寄存器
reg tx_done_reg;           // 发送完成寄存器

// 状态机
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        state <= IDLE;
        tx <= 1'b1;
        bps_cnt <= 16'd0;
        bit_cnt <= 4'd0;
        tx_done_reg <= 1'b0;
    end else begin
        tx_done_reg <= 1'b0;
        case (state)
            IDLE: begin
                tx <= 1'b1;
                if (pi_flag) begin
                    state <= START;
                    tx_data <= pi_data;
                    bps_cnt <= 16'd0;
                end
            end
            
            START: begin
                tx <= 1'b0;
                if (bps_cnt == BPS_CNT - 1) begin
                    state <= SEND;
                    bps_cnt <= 16'd0;
                    bit_cnt <= 4'd0;
                end else begin
                    bps_cnt <= bps_cnt + 1'b1;
                end
            end
            
            SEND: begin
                tx <= tx_data[bit_cnt];
                if (bps_cnt == BPS_CNT - 1) begin
                    bps_cnt <= 16'd0;
                    if (bit_cnt == 4'd7) begin
                        state <= STOP;
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end else begin
                    bps_cnt <= bps_cnt + 1'b1;
                end
            end
            
            STOP: begin
                tx <= 1'b1;
                if (bps_cnt == BPS_CNT - 1) begin
                    state <= IDLE;
                    tx_done_reg <= 1'b1;
                    bps_cnt <= 16'd0;
                end else begin
                    bps_cnt <= bps_cnt + 1'b1;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

assign tx_done = tx_done_reg;

endmodule