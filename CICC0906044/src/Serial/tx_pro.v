module tx_pro #(
    parameter UART_BPS  = 'd9600,      // 波特率
    parameter CLK_FREQ  = 'd50_000_000 // 系统时钟频率
)(
    input   wire        sys_clk,       // 系统时钟
    input   wire        sys_rst_n,     // 复位（低有效）
    input   wire        tx_flag,       // 发送启动信号
    input   wire [7:0]  data_len,      // 数据长度（字节数）
    input   wire [7:0]  data_in [0:20], // 输入数据数组
    input   wire        use_header,    // 是否使用包头（1启用）
    input   wire        use_trailer,   // 是否使用包尾（1启用）
    output  wire        tx,            // UART 发送线
    output  wire        tx_complete,   // 发送完成标志
    output  wire [7:0]  tx_count       // 当前发送字节计数
);

// 状态定义
parameter [2:0]
    IDLE      = 3'd0,    // 空闲状态
    PRE_START = 3'd1,    // 发送前准备
    HEADER    = 3'd2,    // 包头发送
    DATA_BYTE = 3'd3,    // 数据发送
    TRAILER   = 3'd4,    // 包尾发送
    DONE      = 3'd5;    // 发送完成

// 寄存器定义
reg [2:0]   state;          // 状态机当前状态
reg [7:0]   pi_data;        // 待发送数据
reg         pi_flag;        // 发送触发信号
wire        tx_done;        // UART 单字节发送完成
reg         complete_reg;   // 发送完成寄存器
reg [7:0]   data_len_reg;   // 数据长度缓存
reg [7:0]   data_in_reg [0:20]; // 输入数据缓存
reg [7:0]   byte_counter;   // 当前发送字节索引
integer i;
// 包头包尾定义（可参数化）
parameter [7:0] HEADER_BYTE  = 8'h11;
parameter [7:0] TRAILER_BYTE = 8'h22;

// 数据选择逻辑
always @(*) begin
    case (state)
        HEADER:   pi_data = HEADER_BYTE;     // 发送包头
        DATA_BYTE: pi_data = data_in_reg[byte_counter]; // 发送数据
        TRAILER: pi_data = TRAILER_BYTE;     // 发送包尾
        default: pi_data = 8'h00;            // 默认值
    endcase
end
// 状态机控制
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        state <= IDLE;
        pi_flag <= 1'b0;
        complete_reg <= 1'b0;
        byte_counter <= 8'd0;
        data_len_reg <= 8'd0;
        for (i = 0; i < 20; i = i + 1) 
            data_in_reg[i] <= 8'h00;
    end else begin
        pi_flag <= 1'b0;  // 默认拉低，避免重复发送
        complete_reg <= 1'b0;

        case (state)
            IDLE: begin
                if (tx_flag) begin
                    state <= PRE_START;
                    data_len_reg <= data_len;
                    // 只缓存有效数据，其余清零
                    for (i = 0; i < 20; i = i + 1)
                        data_in_reg[i] <= (i < data_len) ? data_in[i] : 8'h00;
                end
            end

            PRE_START: begin
                if (use_header) begin
                    state <= HEADER;
                    pi_flag <= 1'b1;  // 启动包头发送
                end else begin
                    state <= DATA_BYTE;
                    byte_counter <= 8'd0;
                    pi_flag <= 1'b1;  // 直接启动数据发送
                end
            end

            HEADER: begin
                if (tx_done) begin
                    state <= DATA_BYTE;
                    byte_counter <= 8'd0;
                    pi_flag <= 1'b1;  // 启动数据发送
                end
            end

            DATA_BYTE: begin
                if (tx_done) begin
                    if (byte_counter < data_len_reg - 1) begin
                        byte_counter <= byte_counter + 1;
                        pi_flag <= 1'b1;  // 继续发送下一个字节
                    end else begin
                        if (use_trailer) begin
                            state <= TRAILER;
                            pi_flag <= 1'b1;  // 启动包尾发送
                        end else begin
                            state <= DONE;
                            complete_reg <= 1'b1;  // 发送完成
                        end
                    end
                end
            end

            TRAILER: begin
                if (tx_done) begin
                    state <= DONE;
                    complete_reg <= 1'b1;  // 发送完成
                end
            end

            DONE: begin
                state <= IDLE;  // 回到空闲状态
            end
        endcase
    end
end

// UART 发送模块实例化
uart_tx #(
    .UART_BPS(UART_BPS),
    .CLK_FREQ(CLK_FREQ)
) uart_tx_inst (
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .pi_data(pi_data),
    .pi_flag(pi_flag),
    .tx(tx),
    .tx_done(tx_done)
);

// 输出赋值
assign tx_complete = complete_reg;
assign tx_count = byte_counter;

endmodule