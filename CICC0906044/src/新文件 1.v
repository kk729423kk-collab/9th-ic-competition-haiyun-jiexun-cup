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
    output reg sys_finish
);

// 参数定义保持不变
localparam SHAPE_IRREGULAR = 2'b00;
localparam SHAPE_HEXAGON   = 2'b01;
localparam SHAPE_CIRCLE    = 2'b10;
localparam SHAPE_SQUARE    = 2'b11;

localparam COLOR_RED    = 2'b00;
localparam COLOR_BLUE   = 2'b01;
localparam COLOR_YELLOW = 2'b10;
localparam COLOR_BLACK  = 2'b11;

// 状态机编码优化（使用独热码减少逻辑层数）
localparam [4:0] 
    S_IDLE       = 5'b00001,
    S_FIND_DIFF  = 5'b00010,
    S_REQ_VISION = 5'b00100,
    S_WAIT_ARM   = 5'b01000,
    SYS_FINISH   = 5'b10000;

reg [4:0] state;  // 改为独热码编码
// 关键修改：地址打拍设计
reg [4:0] current_address;  // 周期N的地址（打拍前）
reg [4:0] delayed_address; // 周期N+1的地址（打拍后）
wire [6:0] rom_data_out;   // 周期N+1的数据（对应delayed_address）

// ROM实例化（数据延迟1周期）
target_init_rom rom_inst (
    .address(current_address), // 使用打拍前的地址
    .clock(clk),
    .q(rom_data_out)           // 输出对应delayed_address的数据
);
    
// 主状态机
always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        state <= S_IDLE;
        current_address <= 5'd0;
        delayed_address <= 5'd0;
        sys_finish <= 1'b0;
        vision_pos <= 5'd0;
        req_vision <= 1'b0;
        req_color <= 2'b0;
        req_shape <= 2'b0;
        req_angle <= 2'b0;
    end else begin
        // 地址打拍（关键时序对齐）
        delayed_address <= current_address;
        
        case(state)
            S_IDLE: begin
                sys_finish <= 1'b0;
                req_vision <= 1'b0;
                if(sys_start) begin
                    state <= S_FIND_DIFF;
                    current_address <= 5'd0;  // 周期0：请求地址0
                    delayed_address <= 5'd0; // 初始化打拍地址
                end
            end
            
            S_FIND_DIFF: begin
                req_vision <= 1'b0;
          
                if(rom_data_out[0]) begin  // 检查打拍地址的数据
                    vision_pos <= delayed_address; // 使用打拍后的地址
                    req_color <= rom_data_out[6:5];
                    req_shape <= rom_data_out[4:3];
                    req_angle <= rom_data_out[2:1];
                    state <= S_REQ_VISION;
                end else if(current_address < 5'd23) begin
                    current_address <= current_address + 1; // 更新下个地址
                end 
            end
            
            S_REQ_VISION: begin
                req_vision <= 1'b1;
                if(vision_ack) begin
                    req_vision <= 1'b0;
                    state <= S_WAIT_ARM;
                end
            end
            S_WAIT_ARM: begin
                if(arm_done) begin
                    if(current_address <= 5'd23) begin
                        current_address <= current_address + 1;
                        state <= S_FIND_DIFF;
                    end 
                    else begin
                        state <= SYS_FINISH;
                    end
                end
            end
            
            SYS_FINISH: begin
                sys_finish <= 1'b1;
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule