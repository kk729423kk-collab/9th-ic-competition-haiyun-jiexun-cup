`timescale 1ns/1ns
module shape_recognition(
    input               clk,
    input               rst_n,
    input               per_frame_vsync,
    input               per_frame_href,
    input               per_frame_clken,
    input               per_img_Bit,
    input    [9:0]      MIN_DIST,
    input               req_vision,
    
    output  reg  [42:0] target_out [3:0],
    output  reg  [13:0] area_out [3:0],
    output  reg  [9:0]  first_x [3:0],
    output  reg  [9:0]  last_x [3:0]
);

parameter   [9:0]   IMG_HDISP = 10'd640;
parameter   [9:0]   IMG_VDISP = 10'd480;

reg         per_frame_vsync_r;
reg         per_frame_href_r; 
reg         per_frame_clken_r;
reg         per_img_Bit_r;
reg         req_vision_dly;

// 信号同步
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        per_frame_vsync_r <= 0;
        per_frame_href_r <= 0;
        per_frame_clken_r <= 0;
        per_img_Bit_r <= 0;
        req_vision_dly <= 0;
    end
    else begin
        per_frame_vsync_r <= per_frame_vsync;
        per_frame_href_r <= per_frame_href;
        per_frame_clken_r <= per_frame_clken;
        per_img_Bit_r <= per_img_Bit;
        req_vision_dly <= req_vision;
    end
end

// 边沿检测
wire vsync_pos_flag;
wire req_vision_pos_flag;
assign vsync_pos_flag = per_frame_vsync & (~per_frame_vsync_r);
assign req_vision_pos_flag = (~req_vision_dly) & req_vision;

// 像素坐标计数器
reg [9:0] x_cnt;
reg [9:0] y_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_cnt <= 10'd0;
        y_cnt <= 10'd0;
    end
    else if (vsync_pos_flag) begin
        x_cnt <= 10'd0;
        y_cnt <= 10'd0;
    end
    else if (per_frame_clken) begin
        if (x_cnt < IMG_HDISP - 1) begin
            x_cnt <= x_cnt + 1'b1;
            y_cnt <= y_cnt;
        end
        else begin
            x_cnt <= 10'd0;
            y_cnt <= y_cnt + 1'b1;
        end
    end
end

// 坐标寄存器
reg [9:0] x_cnt_r;
reg [9:0] y_cnt_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_cnt_r <= 10'd0;
        y_cnt_r <= 10'd0;
    end
    else begin
        x_cnt_r <= x_cnt;
        y_cnt_r <= y_cnt;
    end
end

// 帧计数器
reg [2:0] vsync_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        vsync_cnt <= 3'b000;
    else if (req_vision_pos_flag)
        vsync_cnt <= 3'b000;
    else if (vsync_pos_flag)
        vsync_cnt <= vsync_cnt + 1'b1;
    else if (vsync_cnt >= 3'b011)
        vsync_cnt <= 3'b000;
    else
        vsync_cnt <= vsync_cnt; 
end

// 目标信息存储
reg  [40:0] target_pos [3:0];
reg  [42:0] target_pos_out [3:0];
reg  [9:0]  first_x_temp [3:0];
reg  [9:0]  last_x_temp [3:0];

// 目标边界定义
wire [3:0]  target_flag;
wire [9:0]  target_left [3:0];
wire [9:0]  target_right [3:0];
wire [9:0]  target_top [3:0];
wire [9:0]  target_bottom [3:0];

wire [9:0]  target_boarder_left [3:0];
wire [9:0]  target_boarder_right [3:0];
wire [9:0]  target_boarder_top [3:0];
wire [9:0]  target_boarder_bottom [3:0];

generate
    genvar i;
    for (i=0; i<4; i=i+1) begin: voluation
        assign target_flag[i] = target_pos[i][40];

        assign target_bottom[i] = (target_pos[i][39:30] < IMG_VDISP - 1 - MIN_DIST) ? 
                                (target_pos[i][39:30] + MIN_DIST) : IMG_VDISP - 1;
        assign target_right[i] = (target_pos[i][29:20] < IMG_HDISP - 1 - MIN_DIST) ? 
                               (target_pos[i][29:20] + MIN_DIST) : IMG_HDISP - 1;
        assign target_top[i] = (target_pos[i][19:10] > MIN_DIST) ? 
                             (target_pos[i][19:10] - MIN_DIST) : 10'd0;
        assign target_left[i] = (target_pos[i][9:0] > MIN_DIST) ? 
                              (target_pos[i][9:0] - MIN_DIST) : 10'd0;

        assign target_boarder_bottom[i] = target_pos_out[i][39:30];
        assign target_boarder_right[i] = target_pos_out[i][29:20];
        assign target_boarder_top[i] = target_pos_out[i][19:10];
        assign target_boarder_left[i] = target_pos_out[i][9:0];
    end
endgenerate

// 目标检测逻辑
integer j;
reg [2:0] target_cnt;
reg [3:0] new_target_flag;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (j=0; j<4; j=j+1) begin
            target_pos[j] <= {1'b0, 10'd0, 10'd0, 10'd0, 10'd0};
            first_x_temp[j] <= 10'd0;
            last_x_temp[j] <= 10'd0;
        end
        new_target_flag <= 4'd0;
        target_cnt <= 3'd0;
    end
    else if (req_vision_pos_flag) begin
        for (j=0; j<4; j=j+1) begin
            target_pos[j] <= {1'b0, 10'd0, 10'd0, 10'd0, 10'd0};
            first_x_temp[j] <= 10'd0;
            last_x_temp[j] <= 10'd0;
        end
        new_target_flag <= 4'd0;
        target_cnt <= 3'd0;
    end
    else if (vsync_pos_flag && (vsync_cnt == 3'b010)) begin
        for (j=0; j<4; j=j+1) begin
            target_pos[j] <= {1'b0, 10'd0, 10'd0, 10'd0, 10'd0};
        end
        new_target_flag <= 4'd0;
        target_cnt <= 3'd0;
    end
    else begin 
        // 检测新目标
        if (per_frame_clken && per_img_Bit && (vsync_cnt == 3'b000)) begin
            for (j=0; j<4; j=j+1) begin
                if (target_flag[j] == 1'b0) begin
                    new_target_flag[j] <= 1'b1;
                end
                else begin
                    if ((x_cnt < target_left[j]) || (x_cnt > target_right[j]) || 
                        (y_cnt < target_top[j]) || (y_cnt > target_bottom[j])) begin
                        new_target_flag[j] <= 1'b1;
                    end
                    else begin
                        new_target_flag[j] <= 1'b0;
                    end
                end
            end
        end
        else begin
            new_target_flag <= 4'd0;
        end
    
        // 更新目标列表
        if (per_frame_clken_r && per_img_Bit_r && (vsync_cnt == 3'b000)) begin
            if (new_target_flag == 4'b1111) begin
                target_pos[target_cnt] <= {1'b1, y_cnt_r, x_cnt_r, y_cnt_r, x_cnt_r};
                first_x_temp[target_cnt] <= x_cnt_r;
                target_cnt <= target_cnt + 1'b1;
            end
            else if (new_target_flag > 4'd0) begin
                for (j=0; j<4; j=j+1) begin
                    if (new_target_flag[j] == 1'b0) begin 
                        target_pos[j][40] <= 1'b1;
                        if (x_cnt_r < target_pos[j][9:0])
                            target_pos[j][9:0] <= x_cnt_r;
                        if (x_cnt_r > target_pos[j][29:20])
                            target_pos[j][29:20] <= x_cnt_r;
                        if (y_cnt_r < target_pos[j][19:10])
                            target_pos[j][19:10] <= y_cnt_r;
                        if (y_cnt_r > target_pos[j][39:30]) begin
                            target_pos[j][39:30] <= y_cnt_r;
                            last_x_temp[j] <= x_cnt_r;
                        end
                    end
                end
            end
        end
    end
end

// 目标1的垂直投影
reg  [13:0] one_sum;
reg         one_ram_wr;
wire [9:0]  one_ram_wr_data;
wire [9:0]  one_ram_rd_data;

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        one_ram_wr <= 1'b0;
    else if (per_frame_clken && ((vsync_cnt == 3'b001) || (vsync_cnt == 3'b010)))
        one_ram_wr <= 1'b1;
    else
        one_ram_wr <= 1'b0;
end

assign one_ram_wr_data = (y_cnt == 10'd0) ? 10'd0 : 
    ((x_cnt > target_boarder_left[0]) && (x_cnt < target_boarder_right[0]) && 
     (y_cnt > target_boarder_top[0]) && (y_cnt < target_boarder_bottom[0]))
     ? (one_ram_rd_data + per_img_Bit_r) : one_ram_rd_data;

ram u_projection_ram (
    .wrclock (clk),
    .wren (one_ram_wr),
    .wraddress (x_cnt_r),
    .data (one_ram_wr_data),
    .rdclock (clk),
    .rdaddress (x_cnt),
    .q (one_ram_rd_data)
);

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) 
        one_sum <= 14'd0;
    else if ((y_cnt == target_boarder_bottom[0] + 1) && (per_frame_clken))
        one_sum <= one_sum + one_ram_rd_data;
    else if (vsync_pos_flag)
        one_sum <= 14'd0;
    else
        one_sum <= one_sum;
end    

// 目标2的垂直投影
reg  [13:0] two_sum;
reg         two_ram_wr;
wire [9:0]  two_ram_wr_data;
wire [9:0]  two_ram_rd_data;

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        two_ram_wr <= 1'b0;
    else if (per_frame_clken && ((vsync_cnt == 3'b001) || (vsync_cnt == 3'b010)))
        two_ram_wr <= 1'b1;
    else
        two_ram_wr <= 1'b0;
end

assign two_ram_wr_data = (y_cnt == 10'd0) ? 10'd0 : 
    ((x_cnt > target_boarder_left[1]) && (x_cnt < target_boarder_right[1]) && 
     (y_cnt > target_boarder_top[1]) && (y_cnt < target_boarder_bottom[1]))
     ? (two_ram_rd_data + per_img_Bit_r) : two_ram_rd_data;

ram u1projection_ram (
    .wrclock (clk),
    .wren (two_ram_wr),
    .wraddress (x_cnt_r),
    .data (two_ram_wr_data),
    .rdclock (clk),
    .rdaddress (x_cnt),
    .q (two_ram_rd_data)
);

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) 
        two_sum <= 14'd0;
    else if ((y_cnt == target_boarder_bottom[1] + 1) && (per_frame_clken))
        two_sum <= two_sum + two_ram_rd_data;
    else if (vsync_pos_flag)
        two_sum <= 14'd0;
    else
        two_sum <= two_sum;
end    

// 目标3的垂直投影
reg  [13:0] three_sum;
reg         three_ram_wr;
wire [9:0]  three_ram_wr_data;
wire [9:0]  three_ram_rd_data;

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        three_ram_wr <= 1'b0;
    else if (per_frame_clken && ((vsync_cnt == 3'b001) || (vsync_cnt == 3'b010)))
        three_ram_wr <= 1'b1;
    else
        three_ram_wr <= 1'b0;
end

assign three_ram_wr_data = (y_cnt == 10'd0) ? 10'd0 : 
    ((x_cnt > target_boarder_left[2]) && (x_cnt < target_boarder_right[2]) && 
     (y_cnt > target_boarder_top[2]) && (y_cnt < target_boarder_bottom[2]))
     ? (three_ram_rd_data + per_img_Bit_r) : three_ram_rd_data;

ram u2_projection_ram (
    .wrclock (clk),
    .wren (three_ram_wr),
    .wraddress (x_cnt_r),
    .data (three_ram_wr_data),
    .rdclock (clk),
    .rdaddress (x_cnt),
    .q (three_ram_rd_data)
);

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) 
        three_sum <= 14'd0;
    else if ((y_cnt == target_boarder_bottom[2] + 1) && (per_frame_clken))
        three_sum <= three_sum + three_ram_rd_data;
    else if (vsync_pos_flag)
        three_sum <= 14'd0;
    else
        three_sum <= three_sum;
end    

// 目标4的垂直投影
reg  [13:0] four_sum;
reg         four_ram_wr;
wire [9:0]  four_ram_wr_data;
wire [9:0]  four_ram_rd_data;

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        four_ram_wr <= 1'b0;
    else if (per_frame_clken && ((vsync_cnt == 3'b001) || (vsync_cnt == 3'b010)))
        four_ram_wr <= 1'b1;
    else
        four_ram_wr <= 1'b0;
end

assign four_ram_wr_data = (y_cnt == 10'd0) ? 10'd0 : 
    ((x_cnt > target_boarder_left[3]) && (x_cnt < target_boarder_right[3]) && 
     (y_cnt > target_boarder_top[3]) && (y_cnt < target_boarder_bottom[3]))
     ? (four_ram_rd_data + per_img_Bit_r) : four_ram_rd_data;

ram u3_projection_ram (
    .wrclock (clk),
    .wren (four_ram_wr),
    .wraddress (x_cnt_r),
    .data (four_ram_wr_data),
    .rdclock (clk),
    .rdaddress (x_cnt),
    .q (four_ram_rd_data)
);

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) 
        four_sum <= 14'd0;
    else if ((y_cnt == target_boarder_bottom[3] + 1) && (per_frame_clken))
        four_sum <= four_sum + four_ram_rd_data;
    else if (vsync_pos_flag)
        four_sum <= 14'd0;
    else
        four_sum <= four_sum;
end    

// 形状判断
localparam SHAPE_IRREGULAR = 2'b00;
localparam SHAPE_HEXAGON   = 2'b01;
localparam SHAPE_CIRCLE    = 2'b10;
localparam SHAPE_SQUARE    = 2'b11;

parameter SQUARE_MIN = 14'd1300;
parameter CIRCLE_MIN = 14'd1000;
parameter HEXAGON_MIN = 14'd850;
parameter TRIANGLE_MIN = 14'd500;

wire [13:0] curr_area [3:0];
assign curr_area[0] = one_sum;
assign curr_area[1] = two_sum;
assign curr_area[2] = three_sum;
assign curr_area[3] = four_sum;

integer k;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k=0; k<4; k=k+1) begin
            target_pos_out[k] <= {2'b00, 1'b0, 10'd0, 10'd0, 10'd0, 10'd0};
            area_out[k] <= 14'd0;
        end
    end
    else if (req_vision_pos_flag) begin
        for (k=0; k<4; k=k+1) begin
            target_pos_out[k] <= {2'b00, 1'b0, 10'd0, 10'd0, 10'd0, 10'd0};
            area_out[k] <= 14'd0;
        end
    end
    else if (vsync_pos_flag) begin
        case (vsync_cnt)
            3'b000: begin
                for (k=0; k<4; k=k+1) begin
                    target_pos_out[k] <= target_pos[k];
                end
            end
            3'd2: begin
                for (k=0; k<4; k=k+1) begin
                    area_out[k] <= curr_area[k];
                    if (curr_area[k] >= SQUARE_MIN)
                        target_pos_out[k][42:41] <= SHAPE_SQUARE;
                    else if (curr_area[k] >= CIRCLE_MIN)
                        target_pos_out[k][42:41] <= SHAPE_CIRCLE;
                    else if (curr_area[k] >= HEXAGON_MIN)
                        target_pos_out[k][42:41] <= SHAPE_HEXAGON;
                    else if (curr_area[k] >= TRIANGLE_MIN)
                        target_pos_out[k][42:41] <= SHAPE_IRREGULAR;
                    else
                        target_pos_out[k][42:41] <= SHAPE_IRREGULAR;
                end
            end
        endcase
    end
end

// 最终输出
integer a;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (a=0; a<4; a=a+1) begin
            target_out[a] <= {2'b0, 1'b0, 10'd0, 10'd0, 10'd0, 10'd0};
            first_x[a] <= 10'd0;
            last_x[a] <= 10'd0;
        end
    end
    else if (req_vision_pos_flag) begin
        for (a=0; a<4; a=a+1) begin
            target_out[a] <= {2'b0, 1'b0, 10'd0, 10'd0, 10'd0, 10'd0};
            first_x[a] <= 10'd0;
            last_x[a] <= 10'd0;
        end
    end
    else if (vsync_cnt == 3'b011) begin
        for (a=0; a<4; a=a+1) begin
            target_out[a] <= target_pos_out[a];
            first_x[a] <= first_x_temp[a];
            last_x[a] <= last_x_temp[a];
        end
    end
end

endmodule