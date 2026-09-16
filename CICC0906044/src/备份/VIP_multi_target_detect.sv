`timescale 1ns/1ns
module shape_recognition(
    // 全局时钟
    input               clk,                // CMOS视频像素时钟
    input               rst_n,              // 全局复位
    
    // 图像数据输入
    input               per_frame_vsync,    // 垂直同步信号
    input               per_frame_href,     // 行有效信号  
    input               per_frame_clken,    // 像素时钟使能
    input               per_img_Bit,        // 二值化图像数据
    input    [9:0]      MIN_DIST,           // 最小间隔距离
    
    // 输出接口
    output  reg  [42:0] target_out [3:0],   // 目标信息输出（增加到4个）
    output  reg  [13:0] area_out [3:0]      // 面积输出（增加到4个）
);

// 图像参数定义
parameter   [9:0]   IMG_HDISP = 10'd640;    // 图像水平分辨率
parameter   [9:0]   IMG_VDISP = 10'd480;    // 图像垂直分辨率

// 输入信号寄存
reg         per_frame_vsync_r;
reg         per_frame_href_r; 
reg         per_frame_clken_r;
reg         per_img_Bit_r;

//------------------------------------------
// 信号同步（延迟1个时钟周期）
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        per_frame_vsync_r <= 0;
        per_frame_href_r <= 0;
        per_frame_clken_r <= 0;
        per_img_Bit_r <= 0;
    end
    else begin
        per_frame_vsync_r <= per_frame_vsync;
        per_frame_href_r <= per_frame_href;
        per_frame_clken_r <= per_frame_clken;
        per_img_Bit_r <= per_img_Bit;
    end
end

// 边沿检测
wire vsync_pos_flag;  // 上升沿
wire vsync_neg_flag;  // 下降沿

assign vsync_pos_flag = per_frame_vsync & (~per_frame_vsync_r);
assign vsync_neg_flag = (~per_frame_vsync) & per_frame_vsync_r;

//------------------------------------------
// 像素坐标计数器
reg [9:0] x_cnt;  // 水平计数器
reg [9:0] y_cnt;  // 垂直计数器

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        x_cnt <= 10'd0;
        y_cnt <= 10'd0;
    end
    else if(vsync_pos_flag) begin
        x_cnt <= 10'd0;
        y_cnt <= 10'd0;
    end
    else if(per_frame_clken) begin
        if(x_cnt < IMG_HDISP - 1) begin
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

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        x_cnt_r <= 10'd0;
        y_cnt_r <= 10'd0;
    end 
    else begin
        x_cnt_r <= x_cnt;
        y_cnt_r <= y_cnt;
    end
end

//---------------------------------------------
// 帧计数器（3帧循环）
reg [2:0] vsync_cnt;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
       vsync_cnt <= 3'b000;
    else if(vsync_pos_flag)
       vsync_cnt <= vsync_cnt + 1'b1;
    else if(vsync_cnt >= 3'b011)
       vsync_cnt <= 3'b000;
    else
       vsync_cnt <= vsync_cnt; 
end

// 目标信息存储（增加到4个）
reg  [40:0] target_pos [3:0];      // 目标位置信息
reg  [42:0] target_pos_out [3:0];  // 输出目标信息

// 目标边界定义（增加到4个）
wire [3:0]  target_flag;           // 目标有效标志
wire [9:0]  target_left    [3:0];  // 左边界
wire [9:0]  target_right   [3:0];  // 右边界
wire [9:0]  target_top     [3:0];  // 上边界
wire [9:0]  target_bottom  [3:0];  // 下边界

wire [9:0]  target_boarder_left    [3:0];
wire [9:0]  target_boarder_right   [3:0];
wire [9:0]  target_boarder_top     [3:0];
wire [9:0]  target_boarder_bottom  [3:0];

// 目标中心点（增加到4个）
reg [9:0] one_x [3:0];
reg [9:0] one_y [3:0];

// 边界扩展阈值
reg [6:0] valid_x_add = 7'd100;  // X方向扩展阈值
reg [7:0] valid_y_add = 8'd140;  // Y方向扩展阈值

// 生成目标边界参数（修改为4个目标）
generate
genvar i;
    for(i=0;i<4;i=i+1) begin: voluation
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

//-------------------------------------------
// 目标检测逻辑（修改为支持4个目标）
integer j;
reg [2:0] target_cnt;             // 目标计数器（最大支持8个）
reg [3:0] new_target_flag;        // 新目标检测标志（增加到4位）

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(j=0;j<4;j=j+1) begin
            target_pos[j] <= {1'b0,10'd0,10'd0,10'd0,10'd0};
            one_x[j] <= 10'd640;
            one_y[j] <= 10'b0;
        end
        new_target_flag <= 4'd0;
        target_cnt <= 3'd0;
    end
    else if((vsync_pos_flag) && (vsync_cnt == 3'b010)) begin
        for(j=0;j<4;j=j+1) begin
            target_pos[j] <= {1'b0,10'd0,10'd0,10'd0,10'd0};
            one_x[j] <= 10'd640;
            one_y[j] <= 10'b0;
        end
        new_target_flag <= 4'd0;
        target_cnt <= 3'd0;
    end
    else begin 
        // 第一个时钟周期：检测新目标
        if(per_frame_clken && per_img_Bit && (vsync_cnt == 3'b000)) begin
           for(j=0;j<4;j=j+1) begin
               if(target_flag[j] == 1'b0) begin
                   new_target_flag[j] <= 1'b1;
               end
               else begin
                   if(((x_cnt < target_left[j]) && ((y_cnt > one_y[j] + 30) || 
                       (x_cnt < one_x[j] - 100) || (x_cnt > one_x[j]))) || 
                       (x_cnt > target_right[j]) || (y_cnt < target_top[j]) || 
                       (y_cnt > target_bottom[j])) begin
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
    
        // 第二个时钟周期：更新目标列表
        if(per_frame_clken_r && per_img_Bit_r && (vsync_cnt == 3'b000)) begin
            if(new_target_flag == 4'b1111) begin  // 检测到新目标
                if(target_cnt < 4) begin  // 只处理前4个目标
                    target_pos[target_cnt] <= {1'b1,y_cnt_r,x_cnt_r,y_cnt_r,x_cnt_r};
                    one_x[target_cnt] <= x_cnt_r;
                    one_y[target_cnt] <= y_cnt_r;
                    target_cnt <= target_cnt + 1'b1;
                end
            end
            else if(new_target_flag > 4'd0) begin
                for(j=0;j<4;j=j+1) begin
                    if(new_target_flag[j] == 1'b0) begin 
                        target_pos[j][40] <= 1'b1;
                        if((x_cnt_r < target_pos[j][9:0]) && (x_cnt_r > one_x[j] - valid_x_add))
                            target_pos[j][9:0] <= x_cnt_r;
                        if((x_cnt_r > target_pos[j][29:20]) && (x_cnt_r < one_x[j] + valid_x_add))
                            target_pos[j][29:20] <= x_cnt_r;
                        if((y_cnt_r < target_pos[j][19:10]) && (y_cnt_r > one_y[j] - valid_y_add))
                            target_pos[j][19:10] <= y_cnt_r;
                        if((y_cnt_r > target_pos[j][39:30]) && (y_cnt_r < one_y[j] + valid_y_add))
                            target_pos[j][39:30] <= y_cnt_r;
                    end
                end
            end
        end
    end
end

//------------------------------------------
// 边界检测和面积计算（增加到4个目标）
reg  [9:0] boarder_left [3:0];    // 左边界
reg  [9:0] boarder_right [3:0];   // 右边界

// 目标1的垂直投影
reg  [13:0] one_sum;              // 面积累加器
reg         one_ram_wr;           // RAM写使能
wire [9:0]  one_ram_wr_data;      // RAM写数据
wire [9:0]  one_ram_rd_data;      // RAM读数据

always @ (posedge clk or negedge rst_n) begin
    if(!rst_n)
        one_ram_wr <= 1'b0;
    else if(per_frame_clken && ((vsync_cnt == 3'b001) || (vsync_cnt == 3'b010)))
        one_ram_wr <= 1'b1;
    else
        one_ram_wr <= 1'b0;
end

assign one_ram_wr_data = (y_cnt == 10'd0) ? 10'd0 : // 第一行初始化为0
    ((x_cnt > target_boarder_left[0]) && (x_cnt < target_boarder_right[0]) && 
     (y_cnt > target_boarder_top[0]) && (y_cnt < target_boarder_bottom[0]))
     ? (one_ram_rd_data + per_img_Bit_r) : one_ram_rd_data;

// 投影RAM实例化
ram u_projection_ram (
    .wrclock (clk),
    .wren (one_ram_wr),
    .wraddress (x_cnt_r),
    .data (one_ram_wr_data),
    
    .rdclock (clk),
    .rdaddress (x_cnt),
    .q (one_ram_rd_data)
);

// 面积累加
always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) 
        one_sum <= 14'd0;
    else if((y_cnt == target_boarder_bottom[0] + 1) && (per_frame_clken))
        one_sum <= one_sum + one_ram_rd_data;
    else if(vsync_pos_flag)
        one_sum <= 14'd0;
    else
        one_sum <= one_sum;
end    

// 边界检测
always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        boarder_left[0] <= 10'b0;
        boarder_right[0] <= 10'b0;
     end
    else if((y_cnt == target_boarder_bottom[0] + 1) && (per_frame_clken) && 
            (x_cnt < one_x[0]) && (one_ram_rd_data == 0))
        boarder_left[0] <= x_cnt;
    else if((y_cnt == target_boarder_bottom[0] + 1) && (per_frame_clken) && 
            (x_cnt > one_x[0]) && (one_ram_rd_data == 0))
        boarder_right[0] <= x_cnt;
    else begin
        boarder_left[0] <= boarder_left[0];
        boarder_right[0] <= boarder_right[0];
    end
end    

// 目标2的垂直投影（与目标1类似）
reg  [13:0] two_sum;
reg         two_ram_wr;
wire [9:0]  two_ram_wr_data;
wire [9:0]  two_ram_rd_data;

always @ (posedge clk or negedge rst_n) begin
    if(!rst_n)
        two_ram_wr <= 1'b0;
    else if(per_frame_clken && ((vsync_cnt == 3'b001) || (vsync_cnt == 3'b010)))
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
    if(!rst_n) 
        two_sum <= 14'd0;
    else if((y_cnt == target_boarder_bottom[1] + 1) && (per_frame_clken))
        two_sum <= two_sum + two_ram_rd_data;
    else if(vsync_pos_flag)
        two_sum <= 14'd0;
    else
        two_sum <= two_sum;
end    

always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        boarder_left[1] <= 10'b0;
        boarder_right[1] <= 10'b0;
     end
    else if((y_cnt == target_boarder_bottom[1] + 1) && (per_frame_clken) && 
            (x_cnt < one_x[1]) && (two_ram_rd_data == 0))
        boarder_left[1] <= x_cnt;
    else if((y_cnt == target_boarder_bottom[1] + 1) && (per_frame_clken) && 
            (x_cnt > one_x[1]) && (two_ram_rd_data == 0))
        boarder_right[1] <= x_cnt;
    else begin
        boarder_left[1] <= boarder_left[1];
        boarder_right[1] <= boarder_right[1];
    end
end    

// 目标3的垂直投影（与目标1类似）
reg  [13:0] three_sum;
reg         three_ram_wr;
wire [9:0]  three_ram_wr_data;
wire [9:0]  three_ram_rd_data;

always @ (posedge clk or negedge rst_n) begin
    if(!rst_n)
        three_ram_wr <= 1'b0;
    else if(per_frame_clken && ((vsync_cnt == 3'b001) || (vsync_cnt == 3'b010)))
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
    if(!rst_n) 
        three_sum <= 14'd0;
    else if((y_cnt == target_boarder_bottom[2] + 1) && (per_frame_clken))
        three_sum <= three_sum + three_ram_rd_data;
    else if(vsync_pos_flag)
        three_sum <= 14'd0;
    else
        three_sum <= three_sum;
end    

always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        boarder_left[2] <= 10'b0;
        boarder_right[2] <= 10'b0;
     end
    else if((y_cnt == target_boarder_bottom[2] + 1) && (per_frame_clken) && 
            (x_cnt < one_x[2]) && (three_ram_rd_data == 0))
        boarder_left[2] <= x_cnt;
    else if((y_cnt == target_boarder_bottom[2] + 1) && (per_frame_clken) && 
            (x_cnt > one_x[2]) && (three_ram_rd_data == 0))
        boarder_right[2] <= x_cnt;
    else begin
        boarder_left[2] <= boarder_left[2];
        boarder_right[2] <= boarder_right[2];
    end
end    

// 目标4的垂直投影（新增）
reg  [13:0] four_sum;
reg         four_ram_wr;
wire [9:0]  four_ram_wr_data;
wire [9:0]  four_ram_rd_data;

always @ (posedge clk or negedge rst_n) begin
    if(!rst_n)
        four_ram_wr <= 1'b0;
    else if(per_frame_clken && ((vsync_cnt == 3'b001) || (vsync_cnt == 3'b010)))
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
    if(!rst_n) 
        four_sum <= 14'd0;
    else if((y_cnt == target_boarder_bottom[3] + 1) && (per_frame_clken))
        four_sum <= four_sum + four_ram_rd_data;
    else if(vsync_pos_flag)
        four_sum <= 14'd0;
    else
        four_sum <= four_sum;
end    

always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        boarder_left[3] <= 10'b0;
        boarder_right[3] <= 10'b0;
     end
    else if((y_cnt == target_boarder_bottom[3] + 1) && (per_frame_clken) && 
            (x_cnt < one_x[3]) && (four_ram_rd_data == 0))
        boarder_left[3] <= x_cnt;
    else if((y_cnt == target_boarder_bottom[3] + 1) && (per_frame_clken) && 
            (x_cnt > one_x[3]) && (four_ram_rd_data == 0))
        boarder_right[3] <= x_cnt;
    else begin
        boarder_left[3] <= boarder_left[3];
        boarder_right[3] <= boarder_right[3];
    end
end    

//------------------------------------------
// 目标输出处理（修改为4个目标）
integer k;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        for(k=0;k<4;k=k+1) begin
            target_pos_out[k] <= {2'b0,1'b0,10'd0,10'd0,10'd0,10'd0};
            area_out[k] <= 14'd0;
        end
    end
    else if(vsync_pos_flag && (vsync_cnt == 3'b000)) begin
        for(k=0;k<4;k=k+1) begin
            target_pos_out[k] <= target_pos[k];  
        end
    end
    else if(vsync_pos_flag && (vsync_cnt == 3'b001)) begin
        for(k=0;k<4;k=k+1) begin
            if((target_pos_out[k][9:0] < boarder_left[k]) && (boarder_left[k] < one_x[k]))
                target_pos_out[k][9:0] <= boarder_left[k];
            if((target_pos_out[k][29:20] > boarder_right[k]) && (boarder_right[k] > one_x[k]))
                target_pos_out[k][29:20] <= boarder_right[k];
            if((target_pos_out[k][39:30] - target_pos_out[k][19:10]) < 90)
                target_pos_out[k][19:10] <= target_pos_out[k][39:30] - 90;
        end
    end
    else if(vsync_pos_flag && (vsync_cnt == 3'b010)) begin
        // 目标1形状识别
        if((one_sum > 8000) && (one_sum < 10000)) begin
            target_pos_out[0][42:41] <= 2'b11;          // 正方形 (8300~9500)
            area_out[0] <= one_sum;
        end
        else if((one_sum > 6700) && (one_sum < 8000)) begin
            target_pos_out[0][42:41] <= 2'b10;          // 圆形 (6500~8300)
            area_out[0] <= one_sum;
        end
        else if((one_sum > 4000) && (one_sum < 6700)) begin
            target_pos_out[0][42:41] <= 2'b01;          // 六边形 (5000~6500)
            area_out[0] <= one_sum;
        end
        else if((one_sum > 2000) && (one_sum < 4000)) begin  // 新增三角形识别
            target_pos_out[0][42:41] <= 2'b00;          // 三角形 (面积约为正方形一半)
            area_out[0] <= one_sum;
        end
        else begin
            target_pos_out[0][42:41] <= 2'b00;          // 不规则图形
            area_out[0] <= one_sum;
        end
        
        // 目标2形状识别
        if((two_sum > 8000) && (two_sum < 10000)) begin
            target_pos_out[1][42:41] <= 2'b11;          // 正方形
            area_out[1] <= two_sum;
        end
        else if((two_sum > 6700) && (two_sum < 8000)) begin
            target_pos_out[1][42:41] <= 2'b10;          // 圆形
            area_out[1] <= two_sum;
        end
        else if((two_sum > 4000) && (two_sum < 6700)) begin
            target_pos_out[1][42:41] <= 2'b01;          // 六边形
            area_out[1] <= two_sum;
        end
        else if((two_sum > 2000) && (two_sum < 4000)) begin  // 新增三角形识别
            target_pos_out[1][42:41] <= 2'b00;          // 三角形
            area_out[1] <= two_sum;
        end
        else begin
            target_pos_out[1][42:41] <= 2'b00;          // 不规则图形
            area_out[1] <= two_sum;
        end
        
        // 目标3形状识别
        if((three_sum > 8000) && (three_sum < 10000)) begin
            target_pos_out[2][42:41] <= 2'b11;          // 正方形
            area_out[2] <= three_sum;
        end
        else if((three_sum > 6700) && (three_sum < 8000)) begin
            target_pos_out[2][42:41] <= 2'b10;          // 圆形
            area_out[2] <= three_sum;
        end
        else if((three_sum > 4000) && (three_sum < 6700)) begin
            target_pos_out[2][42:41] <= 2'b01;          // 六边形
            area_out[2] <= three_sum;
        end
        else if((three_sum > 2000) && (three_sum < 4000)) begin  // 新增三角形识别
            target_pos_out[2][42:41] <= 2'b00;          // 三角形
            area_out[2] <= three_sum;
        end
        else begin
            target_pos_out[2][42:41] <= 2'b00;          // 不规则图形
            area_out[2] <= three_sum;
        end
        
        // 目标4形状识别（新增）
        if((four_sum > 8000) && (four_sum < 10000)) begin
            target_pos_out[3][42:41] <= 2'b11;          // 正方形
            area_out[3] <= four_sum;
        end
        else if((four_sum > 6700) && (four_sum < 8000)) begin
            target_pos_out[3][42:41] <= 2'b10;          // 圆形
            area_out[3] <= four_sum;
        end
        else if((four_sum > 4000) && (four_sum < 6700)) begin
            target_pos_out[3][42:41] <= 2'b01;          // 六边形
            area_out[3] <= four_sum;
        end
        else if((four_sum > 2000) && (four_sum < 4000)) begin  // 新增三角形识别
            target_pos_out[3][42:41] <= 2'b00;          // 三角形
            area_out[3] <= four_sum;
        end
        else begin
            target_pos_out[3][42:41] <= 2'b00;          // 不规则图形
            area_out[3] <= four_sum;
        end
    end
end

// 最终输出（修改为4个目标）
integer a;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
        for(a=0;a<4;a=a+1) begin
            target_out[a] <= {2'b0,1'b0,10'd0,10'd0,10'd0,10'd0};
            //area_out[a] <= 14'd0;
        end
    end
    else if((vsync_cnt == 3'b011)) begin
        for(a=0;a<4;a=a+1) begin
            target_out[a] <= target_pos_out[a];
        end
    end
end

endmodule