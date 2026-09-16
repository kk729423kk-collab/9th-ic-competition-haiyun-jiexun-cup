module rx_pro #(
    parameter UART_BPS    = 'd9600,        // 波特率
    parameter CLK_FREQ    = 'd50_000_000,  // 时钟频率
    parameter DATA_FIELDS = 3,             // 数据字段数量(如dat1,dat2,dat3)
    parameter HEADER_BYTE = 8'h11,         // 包头标识
    parameter TRAILER_BYTE= 8'h22          // 包尾标识
)(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        rx,               // UART接收线
    output reg         packet_valid,     // 完整数据包有效标志
    output reg [7:0]   data_out [0:DATA_FIELDS-1], // 输出数据数组
    output reg         rx_error          // 接收错误标志
);

// 状态定义
localparam [2:0]
    IDLE      = 3'd0,
    HEADER    = 3'd1,
    RECEIVE   = 3'd2,
    TRAILER   = 3'd3,
    COMPLETE  = 3'd4;

// 寄存器定义
reg [2:0]   state;
reg [7:0]   data_buf [0:DATA_FIELDS-1];
reg [3:0]   data_cnt;

wire         rx_done;
wire [7:0]   rx_data;

// UART接收模块实例化
uart_rx 
#(
    .UART_BPS(UART_BPS),
    .CLK_FREQ(CLK_FREQ)
)
uart_rx_inst(
    .sys_clk(sys_clk),
    .rst_n(sys_rst_n),
    .rx(rx),
    
    .po_flag(rx_done),
    .po_data(rx_data)
);

// 主状态机
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        state <= IDLE;
        packet_valid <= 1'b0;
        rx_error <= 1'b0;
        data_cnt <= 4'd0;
        for (integer i=0; i<DATA_FIELDS; i=i+1)
            data_buf[i] <= 8'h00;
    end else begin
        packet_valid <= 1'b0;
        
        case (state)
            IDLE: begin
                if (rx_done && rx_data == HEADER_BYTE) begin
                    state <= HEADER;
                    data_cnt <= 4'd0;
                end
            end
            
            HEADER: begin
                if (rx_done) begin
                    state <= RECEIVE;
                    data_buf[data_cnt] <= rx_data;
                    data_cnt <= data_cnt + 1;
                end
            end
            
            RECEIVE: begin
                if (rx_done) begin
                    if (data_cnt < DATA_FIELDS) begin
                        data_buf[data_cnt] <= rx_data;
                        data_cnt <= data_cnt + 1;
                    end else begin
                        state <= TRAILER;
                    end
                end
            end
            
            TRAILER: begin
                //if (rx_done) begin
                    if (rx_data == TRAILER_BYTE) begin
                        state <= COMPLETE;
                        packet_valid <= 1'b1;
                        data_out <= data_buf;
                    end else begin
                        state <= IDLE;
                        rx_error <= 1'b1;
                    end
                //end
            end
            
            COMPLETE: begin
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule