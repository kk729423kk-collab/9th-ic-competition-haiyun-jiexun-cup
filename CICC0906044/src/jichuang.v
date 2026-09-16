module jichuang
(
    input         		sys_clk    ,  //系统时钟
    input         		sys_rst_n  ,  //系统复位，低电平有效
    //摄像头 
    input         		cam_pclk   ,  //cmos 数据像素时钟
    input         		cam_vsync  ,  //cmos 场同步信号
    input         		cam_href   ,  //cmos 行同步信号
    input 	[7:0]  		cam_data   ,  //cmos 数据  
    output        		cam_rst_n  ,  //cmos 复位信号，低电平有效
    output        		cam_pwdn   ,  //cmos 电源休眠模式选择信号
    output        		cam_scl    ,  //cmos SCCB_SCL线
    inout         		cam_sda    ,  //cmos SCCB_SDA线
    //SDRAM 		
    output        		sdram_clk  ,  //SDRAM 时钟
    output        		sdram_cke  ,  //SDRAM 时钟有效
    output        		sdram_cs_n ,  //SDRAM 片选
    output        		sdram_ras_n,  //SDRAM 行有效
    output        		sdram_cas_n,  //SDRAM 列有效
    output        		sdram_we_n ,  //SDRAM 写有效
    output 	[1:0]  		sdram_ba   ,  //SDRAM Bank地址
    output 	[1:0]  		sdram_dqm  ,  //SDRAM 数据掩码
    output 	[12:0] 		sdram_addr ,  //SDRAM 地址
    inout  	[15:0] 		sdram_data ,  //SDRAM 数据    
    //VGA接口                          
    output              vga_hs     ,  
    output              vga_vs     ,  
    output  [15:0]   	vga_rgb     ,
    output pump_ctrl,                  // 气泵控制信号
    // PWM输出到舵机
    output        pwm_servo1,
    output        pwm_servo2,
    output        pwm_servo3,
    output        pwm_servo4,
    output        pwm_servo5,
    
    input switch1                   ,
    input color_switch2              ,
    input color_switch3              ,
    input key_in1                   ,
    input key_in2                   ,
    output [2:0] debug_led          ,
    input   rx                        ,
    output  tx                      
    
);
	
	//parameter define
	parameter  SLAVE_ADDR       = 7'h3c          ;  //OV5640的器件地址7'h3c
	parameter  BIT_CTRL         = 1'b1           ;  //OV5640的字节地址为16位  0:8位 1:16位
	parameter  CLK_FREQ         = 26'd65_000_000 ;  //i2c_dri模块的驱动时钟频率 65MHz
	parameter  I2C_FREQ         = 18'd250_000    ;  //I2C的SCL时钟频率,不超过400KHz
	parameter  CMOS_H_PIXEL     = 24'd640        ;  //CMOS水平方向像素个数,用于设置SDRAM缓存大小
	parameter  CMOS_V_PIXEL     = 24'd480        ;  //CMOS垂直方向像素个数,用于设置SDRAM缓存大小

////////////////////////////////////////////
	wire          clk_100m        ;     //100mhz时钟,SDRAM操作时钟
	wire          clk_100m_shift  ;     //100mhz时钟,SDRAM相位偏移时钟
	wire          clk_65m         ;     //65mhz时钟,提供给IIC驱动时钟 
	wire          clk_25m         ;     
	wire          locked          ;     
	wire          rst_n           ;     
		
	wire          i2c_exec        ;     //I2C触发执行信号
	wire   [23:0] i2c_data        ;     //I2C要配置的地址与数据(高8位地址,低8位数据)          
	wire          cam_init_done   ;     //摄像头初始化完成
	wire          i2c_done        ;     //I2C寄存器配置完成信号
	wire          i2c_dri_clk     ;     //I2C操作时钟
	   
	wire          wr_en           ;     //sdram_ctrl模块写使能
	wire   [15:0] wr_data         ;     //sdram_ctrl模块写数据
	wire          rd_en           ;     //sdram_ctrl模块读使能
	wire   [15:0] rd_data         ;     //sdram_ctrl模块读数据
	wire          sdram_init_done ;     //SDRAM初始化完成
	wire          sys_init_done   ;     //系统初始化完成(sdram初始化+摄像头初始化)	
		
	assign  cam_rst_n     = 1'b1  ;     //不对摄像头硬件复位,固定高电平
	assign  cam_pwdn      = 1'b0  ;     //电源休眠模式选择 0：正常模式 1：电源休眠模式

	assign  rst_n         = sys_rst_n & locked;
	assign  sys_init_done = sdram_init_done & cam_init_done;
////////////////////////////////////////////锁相环
	pll_clk pll_clk(
		.areset             (~sys_rst_n     ),
		.inclk0             (sys_clk        ),
		.c0                 (clk_100m       ),
		.c1                 (clk_100m_shift ),
		.c2                 (clk_25m        ),
		.c3                 (clk_65m        ),
		.locked             (locked         )
    );
////////////////////////////////////////////I2C配置模块
	i2c_ov5640_rgb565_cfg #(
		 .CMOS_H_PIXEL      (CMOS_H_PIXEL   ),
		 .CMOS_V_PIXEL      (CMOS_V_PIXEL   )
	) 
	i2c_ov5640_rgb565_cfg(   
		.clk                (i2c_dri_clk    ),
		.rst_n              (rst_n          ),
		.i2c_done           (i2c_done       ),
		.i2c_exec           (i2c_exec       ),
		.i2c_data           (i2c_data       ),
		.init_done          (cam_init_done  )
    );    
////////////////////////////////////////////I2C驱动模块
	i2c_dri #(
		.SLAVE_ADDR         (SLAVE_ADDR     ),       
		.CLK_FREQ           (CLK_FREQ       ),              
		.I2C_FREQ           (I2C_FREQ       )                
	) 
	i2c_dri(           
		.clk                (clk_65m        ),
		.rst_n              (rst_n          ),   
		.i2c_exec           (i2c_exec       ),   
		.bit_ctrl           (BIT_CTRL       ),   
		.i2c_rh_wl          (1'b0           ),  //固定为0，只用到了IIC驱动的写操作   
		.i2c_addr           (i2c_data[23:8] ),   
		.i2c_data_w         (i2c_data[7:0]  ),   
		.i2c_data_r         (               ),   
		.i2c_done           (i2c_done       ),   
		.scl                (cam_scl        ),   
		.sda                (cam_sda        ),   
		.dri_clk            (i2c_dri_clk    )   //I2C操作时钟
	);
////////////////////////////////////////////
	wire			cmos_vsync ;	 
	wire			cmos_href  ;	 
	wire			cmos_data_vld ;	 
	wire	[15:0]	cmos_data  ;	 	
////////////////////////////////////////////摄像头图像数据采集模块
cmos_capture_data cmos_capture_data(      
	.rst_n              (rst_n & sys_init_done),    
		
	.cam_pclk           (cam_pclk           ),
	.cam_vsync          (cam_vsync          ),
	.cam_href           (cam_href           ),
	.cam_data           (cam_data           ),
		
	.cmos_frame_vsync   (cmos_vsync   ),
	.cmos_frame_href    (cmos_href    ),
	.cmos_frame_valid   (cmos_data_vld ), 
	.cmos_frame_data    (cmos_data    )
);

wire [23:0] rgb888;
assign rgb888={{cmos_data[15:11] , cmos_data[15:13]},
                    {cmos_data[10: 5],cmos_data[10: 9]},
                    {cmos_data[ 4: 0],cmos_data[ 4: 2]}};
wire img_vld;
wire    [15:0] img_data;
wire [23:0]center_hsv;
wire [15:0]	real_x					;
wire [15:0]	real_y					;
wire [3:0]  target_vld;
wire [13:0]   area_out[3:0]    ;
wire [1:0]shape;
wire key_flag1;
wire key_flag2;
wire [42:0] one;
wire zuobiao_vld;
wire [4:0] req_cangku_pos;
wire [1:0] req_color;
wire [1:0] req_shape;
wire [1:0] req_angle;
wire req_vision;
wire vision_ack;
localparam SHAPE_IRREGULAR = 2'b00;  // 三角
localparam SHAPE_HEXAGON   = 2'b01;  // 六边形
localparam SHAPE_CIRCLE    = 2'b10;  // 圆形
localparam SHAPE_SQUARE    = 2'b11;  // 正方形

localparam COLOR_RED    = 2'b00;
localparam COLOR_BLUE   = 2'b01;
localparam COLOR_YELLOW = 2'b10;
localparam COLOR_BLACK  = 2'b11;
wire [1:0] color_select;  // 声明为2位wire
assign color_select = {color_switch2, color_switch3};  // 位拼接赋值
img_pro img_pro_inst
(
	.Clk		        (cam_pclk)			,  	 
	.Rst_n		        (rst_n & sys_init_done)		,	 
  
	.vsync		        (cmos_vsync),	 
	.href		        (cmos_href),	 
	.vld		        (cmos_data_vld)  ,       	 
	.data_in	        (rgb888),	 
    .data_in1           (cmos_data),
    
    .target_color       (req_color),//
    .target_shape       (req_shape),//
    .req_vision         (req_vision),//视觉请求使能
    
	.img_vld	        (img_vld),	 
	.img_data	        (img_data)	,
    .target_vld         (target_vld) ,
    .area_out           (area_out),
    .one                (one),
    
    .real_x             (real_x),         // X坐标(整数mm)
    .real_y             (real_y),         // Y坐标(整数mm)
    .vision_ack         (vision_ack),
    .zuobiao_vld        (zuobiao_vld)     
    //.center_hsv          (center_hsv)
);   
 wire  act_finish;
jixiebi_top jixiebi_top_inst
(
    .clk               (sys_clk) ,
    .rst_n             (sys_rst_n) ,
                     
        
    .target_x          (real_x) ,      // 目标X坐标（有符号）
    .target_y          (real_y) ,      // 目标Y坐标（有符号）
    .target_angle      (req_angle ),
    .target_valid      (zuobiao_vld) ,                // 目标坐标有效信号
                     
     
    .target_cangku_addr(req_cangku_pos),//仓库位置选择 
                      
    
   .pump_ctrl         (pump_ctrl) ,                  // 气泵控制信号
      
   . pwm_servo1(pwm_servo1), //PWM输出到舵机 
   . pwm_servo2(pwm_servo2),
   . pwm_servo3(pwm_servo3),
   . pwm_servo4(pwm_servo4),
   . pwm_servo5(pwm_servo5),
                      
        
    .finish            (act_finish) ,                 // 完成信号
    .state             ()  // 当前状态（调试用）
);
//assign pump_ctrl=switch1;
block_controller    block_controller_inst
(
    .clk(cam_pclk),
    .reset_n(sys_rst_n),
   
    .sys_start(switch1), //系统控制接口
   
    .vision_pos(req_cangku_pos),   // 请求位置索引 //视觉系统接口
    .vision_ack(vision_ack),
    .req_color(req_color),    // 请求颜色
    .req_shape(req_shape),    // 请求形状
    .req_angle(req_angle),    // 请求角度
   .req_vision(req_vision),         // 视觉请求使能

    .arm_done(act_finish),           // 完成信号
    .debug_state(debug_led),
    .sys_finish()          // 系统完成标志
);

sdram_top u_sdram_top(
	.ref_clk            (clk_100m),         //sdram 控制器参考时钟
	.out_clk            (clk_100m_shift),   //用于输出的相位偏移时钟
	.rst_n              (rst_n),            //系统复位

	//用户写端口                              
	.wr_clk             (cam_pclk),         //写端口FIFO: 写时钟
	.wr_en              (img_vld),    //写端口FIFO: 写使能
	.wr_data            (img_data),         //写端口FIFO: 写数据	 

	.wr_min_addr        (24'd0),            //写SDRAM的起始地址
	.wr_max_addr        (CMOS_V_PIXEL*CMOS_H_PIXEL-1),   //写SDRAM的结束地址
	.wr_len             (10'd512),          //写SDRAM时的数据突发长度
	.wr_load            (~rst_n),           //写端口复位: 复位写地址,清空写FIFO

	//用户读端口                              
	.rd_clk             (clk_25m),         //读端口FIFO: 读时钟
	.rd_en              (rd_en),            //读端口FIFO: 读使能
	.rd_data            (rd_data),          //读端口FIFO: 读数据
	
	.rd_min_addr        (24'd0),            //读SDRAM的起始地址
	.rd_max_addr        (CMOS_V_PIXEL*CMOS_H_PIXEL-1),   //读SDRAM的结束地址
	.rd_len             (10'd512),          //从SDRAM中读数据时的突发长度
	.rd_load            (~rst_n),           //读端口复位: 复位读地址,清空读FIFO

	//用户控制端口                                
	.sdram_read_valid   (1'b1),             //SDRAM 读使能
	.sdram_pingpang_en  (1'b1),             //SDRAM 乒乓操作使能
	.sdram_init_done    (sdram_init_done),  //SDRAM 初始化完成标志

	//SDRAM 芯片接口                                
	.sdram_clk          (sdram_clk),        //SDRAM 芯片时钟
	.sdram_cke          (sdram_cke),        //SDRAM 时钟有效
	.sdram_cs_n         (sdram_cs_n),       //SDRAM 片选
	.sdram_ras_n        (sdram_ras_n),      //SDRAM 行有效
	.sdram_cas_n        (sdram_cas_n),      //SDRAM 列有效
	.sdram_we_n         (sdram_we_n),       //SDRAM 写有效
	.sdram_ba           (sdram_ba),         //SDRAM Bank地址
	.sdram_addr         (sdram_addr),       //SDRAM 行/列地址
	.sdram_data         (sdram_data),       //SDRAM 数据
	.sdram_dqm          (sdram_dqm)         //SDRAM 数据掩码
);   
vga_driver vga_driver(
	.vga_clk            (clk_25m        ),  //输入工作时钟,频率25MHz
	.sys_rst_n          (rst_n          ),  //输入复位信号,低电平有效
		
	.vga_hs             (vga_hs         ),  //输出行同步信号     
	.vga_vs             (vga_vs         ),  //输出场同步信号     
	.vga_rgb            (vga_rgb        ),  //输出像素信息    
			
	.pixel_data         (rd_data        ), 	//待显示数据输入
	.data_req   		(rd_en      	)   //数据请求信号
);  


// key_scan    key_scan_inst
// (
    // .sys_clk   (sys_clk) ,   // 系统时钟 50MHz
    // .sys_rst_n (sys_rst_n) ,   // 全局复位
    // .key_in1   (key_in1) ,   // 按键输入信号 1
    // .key_in2   (key_in2) ,   // 按键输入信号 2
             
    // .key_flag1 (key_flag1) ,   // 按键 1 有效标志位
    // .key_flag2 (key_flag2)     // 按键 2 有效标志位
// );

 wire [7:0] tx_buf [0:20];
// assign tx_buf[0] = center_hsv[23:16];
// assign tx_buf[1] = center_hsv[15:8];
// assign tx_buf[2] = center_hsv[7:0];

// assign tx_buf[0] = real_x[15:8];
// assign tx_buf[1] = real_x[7:0];
// assign tx_buf[2] = real_y[15:8];
// assign tx_buf[3] = real_y[7:0];
// assign tx_buf[4] = { 2'd0,area_out[0][13:8]};
// assign tx_buf[5] = area_out[0][7:0];
// assign tx_buf[6] = {5'd0,one[42:40]};
assign tx_buf[0] = one[39:32];
assign tx_buf[1] = one[31:24];
assign tx_buf[2] = one[23:16];
assign tx_buf[3] = one[15:8];
assign tx_buf[4] = one[7:0];
assign tx_buf[5] = 0;
assign tx_buf[6] = 0;

// tx_pro  tx_pro_inst
// (
   // . sys_clk      (sys_clk) ,       // 系统时钟
   // . sys_rst_n    (sys_rst_n) ,     // 复位（低有效）
   // . tx_flag      (key_flag2) ,       // 发送启动信号
   // . data_len     (7) ,      // 数据长度（字节数）
   // . data_in      (tx_buf) , // 输入数据数组
   // . use_header   (1'b1) ,    // 是否使用包头（1启用）
   // . use_trailer  (1'b1) ,   // 是否使用包尾（1启用）
   // . tx           (tx) ,                // UART 发送线
   // . tx_complete  () ,   // 发送完成标志
   // . tx_count     () // 当前发送字节计数
  // );
endmodule