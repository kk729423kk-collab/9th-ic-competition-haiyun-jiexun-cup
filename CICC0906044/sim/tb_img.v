`timescale 1ns / 1ps

module tb_img();

    // 参数定义
    parameter CLK_PERIOD = 10;  // 100MHz时钟

    // 模块接口信号
    reg         Clk;
    reg         Rst_n;
    reg         valid_i;
    reg         img_data_i;
    
    wire [40:0] location_o [0:3];
    wire [15:0] X[0:3];
    wire [15:0] Y[0:3];
    wire [3:0]  Shape[0:3];
    wire [15:0] Area[0:3];
    wire [3:0]  target_count;
    wire        data_valid;

    // 测试控制变量
    integer frame_count = 0;
    integer error_count = 0;

    // 实例化被测模块
    Object_detection_multi #(
        .AREA_SQUARE_MIN(3500),
        .AREA_SQUARE_MAX(4500)
    ) uut (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .valid_i(valid_i),
        .img_data_i(img_data_i),
        .location_o(location_o),
        .X(X),
        .Y(Y),
        .Shape(Shape),
        .Area(Area),
        .target_count(target_count),
        .data_valid(data_valid)
    );

    // 时钟生成
    initial begin
        Clk = 1'b1;
        forever #(CLK_PERIOD/2) Clk = ~Clk;
    end

    // 测试主程序
    initial begin
        // 初始化
        initialize();
        
        // 测试1：单帧单目标检测
        $display("=== 测试1：60x60正方形检测 ===");
        generate_target(240, 200, 60, 60); // 生成60x60目标
        verify_results(1, 4'b0010, 3600);
        
        // 测试2：空帧检测
        $display("=== 测试2：空帧检测 ===");
        generate_blank_frame();
        verify_results(0, 4'b0000, 0);
        
        // 结束测试
        $display("测试完成，错误数：%0d", error_count);
        $finish;
    end

    // 初始化任务
    task initialize;
        begin
            Rst_n = 0;
            valid_i = 0;
            img_data_i = 0;
            #100;
            Rst_n = 1;
            #100;
        end
    endtask

    // 生成目标像素流
    task generate_target;
        input [9:0] x_start;
        input [9:0] y_start;
        input [9:0] width;
        input [9:0] height;
        begin
            $display("生成目标：位置(%0d,%0d) 尺寸%0dx%0d", 
                    x_start, y_start, width, height);
                    
            for (int y = 0; y < 480; y++) begin
                for (int x = 0; x < 640; x++) begin
                    #CLK_PERIOD;
                    valid_i = 1;
                    img_data_i = ((x >= x_start) && (x < x_start+width) && 
                                 (y >= y_start) && (y < y_start+height)) ? 1 : 0;
                end
                #CLK_PERIOD;
                valid_i = 0; // 行间隙
                #(CLK_PERIOD*10); // 模拟行消隐
            end
            #(CLK_PERIOD*1000); // 模拟场消隐
        end
    endtask

    // 生成空帧
    task generate_blank_frame;
        begin
            $display("生成空帧...");
            for (int y = 0; y < 480; y++) begin
                for (int x = 0; x < 640; x++) begin
                    #CLK_PERIOD;
                    valid_i = 1;
                    img_data_i = 0;
                end
                #CLK_PERIOD;
                valid_i = 0;
                #(CLK_PERIOD*10);
            end
            #(CLK_PERIOD*1000);
        end
    endtask

    // 结果验证任务
    task verify_results;
        input [3:0] exp_count;
        input [3:0] exp_shape;
        input [15:0] exp_area;
        begin
            wait(data_valid); // 等待结果输出
            #10;
            
            // 验证目标数量
            if (target_count !== exp_count) begin
                $error("目标数量错误! 期望值:%0d 实际值:%0d", 
                      exp_count, target_count);
                error_count++;
            end
            
            // 验证第一个目标
            if (exp_count > 0) begin
                // 验证形状
                if (Shape[0] !== exp_shape) begin
                    $error("形状错误! 期望值:%4b 实际值:%4b", 
                          exp_shape, Shape[0]);
                    error_count++;
                end
                
                // 验证面积
                if (Area[0] !== exp_area) begin
                    $error("面积错误! 期望值:%0d 实际值:%0d", 
                          exp_area, Area[0]);
                    error_count++;
                end
                
                // 验证坐标范围
                if (location_o[0][9:0] > 300 ||  // x_min
                    location_o[0][29:20] < 240 || // x_max
                    location_o[0][19:10] > 260 || // y_min
                    location_o[0][39:30] < 200)   // y_max
                begin
                    $error("坐标范围异常: x[%0d-%0d] y[%0d-%0d]",
                          location_o[0][9:0], location_o[0][29:20],
                          location_o[0][19:10], location_o[0][39:30]);
                    error_count++;
                end
            end
        end
    endtask

    

endmodule