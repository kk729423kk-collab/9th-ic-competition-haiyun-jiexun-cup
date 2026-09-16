`timescale 1ns/1ns
module data_ctrl(
    // 系统接口
    input               clk,
    input               rst_n,
    input                jixiebi_ack,
    // 目标输入接口
    input       [42:0]  target_out [3:0],
    input       [1:0]   target_shape,
    input               req_vision,
    
    // 实际坐标输出
    output wire [15:0]  real_x,
    output wire [15:0]  real_y,
    output reg          valid,
    output reg          vision_ack
);

// ==============================================
// 参数定义
// ==============================================
parameter VISION_STAB_TIME = 150_000_000; 
parameter X_SCALE = 32'h0000C4EC;  // 0.77 的Q16.16表示
parameter Y_SCALE = 32'h0000C000;  // 0.75 的Q16.16表示
parameter Y_OFFSET = 16'd172;
parameter IMG_CENTER_X = 320;
parameter IMG_CENTER_Y = 240;
//X缩放系数: -0.7759
//Y缩放系数: 0.6818
// ==============================================
// 状态机状态定义（优化顺序）
// ==============================================
localparam 
    ACK_IDLE    = 2'd0,  // 空闲状态
    ACK_STAB    = 2'd1,  // 视觉稳定等待（新增）
    ACK_MATCH   = 2'd2,  // 目标匹配（原ACK_WAIT）
    ACK_SEND    = 2'd3;  // 应答发送

// ==============================================
// 信号声明
// ==============================================
reg [31:0] stab_timer;
reg [1:0] ack_state;
reg [15:0] temp_x, temp_y;
reg [2:0] hold_cnt;
// 目标信息提取（保持不变）
wire [9:0] left [3:0], right [3:0], top [3:0], bottom [3:0];
wire [3:0] target_valid;
wire [1:0] shape_in [3:0];
reg [15:0] center_x [3:0], center_y [3:0];
integer i;
// ==============================================
// 修改后的状态机（关键修改）
// ==============================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ack_state <= ACK_IDLE;
        valid <= 1'b0;
        vision_ack <= 1'b0;
        stab_timer <= 0;
        temp_x <= 0;
        temp_y <= 0;
        hold_cnt<=3'd0;
    end else begin
        case(ack_state)
            // 空闲状态
            ACK_IDLE: begin
                valid <= 1'b0;
                vision_ack <= 1'b0;
                hold_cnt<=3'd0;
                if(req_vision) begin
                    ack_state <= ACK_STAB;
                    stab_timer <= 0;
                end
            end
            
            // 视觉稳定等待（新增）
            ACK_STAB: begin
                if(stab_timer < VISION_STAB_TIME) begin
                    stab_timer <= stab_timer + 1;
                end else begin
                    ack_state <= ACK_MATCH;  // 稳定完成后才匹配目标
                end
            end
            
            // 目标匹配状态
            ACK_MATCH: begin
                stab_timer <= 0;
                // 遍历目标寻找匹配项
                for (i = 0; i < 4; i=i+1) begin
                    if(target_valid[i] && (shape_in[i] == target_shape)) begin
                        temp_x <= center_x[i];
                        temp_y <= center_y[i];
                         vision_ack <= 1'b1;
                         valid <= 1'b1;      // 立即标记有效
                        ack_state <= ACK_SEND;
                    end
                end
            end
            // 应答发送状态
            ACK_SEND: begin
                if(hold_cnt<7)
                begin
                    hold_cnt<=hold_cnt+1'b1;
                end
                else ack_state <= ACK_IDLE;
            end
            
            default: ack_state <= ACK_IDLE;
        endcase
    end
end

// ==============================================
// 其他逻辑（保持不变）
// ==============================================
generate
    genvar k;
    for (k = 0; k < 4; k=k+1) begin : TARGET_EXTRACT
        assign target_valid[k] = target_out[k][40];
        assign shape_in[k] = target_out[k][42:41];
        assign left[k]  = target_out[k][9:0];
        assign right[k] = target_out[k][29:20];
        assign top[k]   = target_out[k][19:10];
        assign bottom[k]= target_out[k][39:30];
    end
endgenerate

always @(*) begin
    for (i = 0; i < 4; i=i+1) begin
        center_x[i] = (left[i] + right[i]) >> 1;
        center_y[i] = (top[i] + bottom[i]) >> 1;
    end
end
assign real_x = valid ? 0-(((temp_x-IMG_CENTER_X)*X_SCALE)>>16) : 16'd0;
assign real_y = valid ? (((temp_y-IMG_CENTER_Y)*Y_SCALE)>>16)+Y_OFFSET : 16'd0;
endmodule