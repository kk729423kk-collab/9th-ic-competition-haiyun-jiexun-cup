`timescale 1ns/1ns

module block_controller(
    input wire clk,
    input wire reset_n,
    input wire sys_start,
    input wire vision_ack,
    output reg [4:0] vision_pos,
    output reg [1:0] req_color,
    output reg [1:0] req_shape,
    output reg [1:0] req_angle,
    output reg req_vision,
    input wire arm_done,
    output [2:0] debug_state,
    output reg sys_finish
);

// 参数定义
localparam SHAPE_IRREGULAR = 2'b00;
localparam SHAPE_HEXAGON   = 2'b01;
localparam SHAPE_CIRCLE    = 2'b10;
localparam SHAPE_SQUARE    = 2'b11;

localparam COLOR_RED    = 2'b00;
localparam COLOR_BLUE   = 2'b01;
localparam COLOR_YELLOW = 2'b10;
localparam COLOR_BLACK  = 2'b11;

// 状态机编码改为二进制（节省触发器资源）
localparam [2:0] 
    S_IDLE       = 3'b000,
    S_FIND_DIFF  = 3'b001,
    S_REQ_VISION = 3'b010,
    S_WAIT_ARM   = 3'b011,
    SYS_FINISH   = 3'b101;

reg [2:0] state;  // 状态寄存器（从5位独热码缩减到3位二进制）
reg [4:0] current_address;
reg [4:0] delayed_address;
wire [6:0] rom_data_out;

// 两级流水线寄存器优化时序
reg arm_done_dly, arm_done_dly1;
assign debug_state=state;
// ROM实例化
target_init_rom rom_inst (
    .address(current_address),
    .clock(clk),
    .q(rom_data_out)
);
// 主状态机
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        state <= S_IDLE;
        current_address <= 5'd0;
        delayed_address <= 5'd0;
        sys_finish <= 1'b0;
        vision_pos <= 5'd0;
        {req_vision, req_color, req_shape, req_angle} <= 7'b0;
        {arm_done_dly, arm_done_dly1} <= 2'b0;
    end else begin
        // 地址和信号打拍
        delayed_address <= current_address;
        arm_done_dly <= arm_done;
        arm_done_dly1 <= arm_done_dly;

        case(state)
            S_IDLE: begin
                sys_finish <= 1'b0;
                req_vision <= 1'b0;
                if(sys_start) begin
                    state <= S_FIND_DIFF;
                    current_address <= 5'd0;
                end
            end
            
            S_FIND_DIFF: begin
                if(rom_data_out[0]) begin  // 有效目标
                    vision_pos <= delayed_address;
                    {req_color, req_shape, req_angle} <= rom_data_out[6:1];
                    req_vision <= 1'b1;
                    state <= S_REQ_VISION;
                end else if(current_address < 5'd23) begin
                    current_address <= current_address + 1;
                end else begin
                    state <= SYS_FINISH;
                end
            end
            
            S_REQ_VISION: begin
                if(vision_ack) begin
                    req_vision <= 1'b0;
                    state <= S_WAIT_ARM;
                end
            end
            
            S_WAIT_ARM: begin
                if(arm_done_dly1) begin
                    if(current_address <= 5'd23) begin
                        current_address <= current_address + 1;
                        state <= S_FIND_DIFF;
                    end else begin
                        state <= SYS_FINISH;
                    end
                end
            end
            
            SYS_FINISH: begin
                sys_finish <= 1'b1;
                // 可选：自动返回IDLE状态
                 state <= S_IDLE;
            end
        endcase
    end
end

endmodule