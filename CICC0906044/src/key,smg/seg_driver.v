module seg_driver(
    input               clk,
    input               rst_n,
    input       [23:0]  digit_in,   // 6x4位数字输入
    input       [5:0]   dot_en,     // 小数点使能
    
    output  reg [5:0]   seg_sel,    // 片选（低有效）
    output  reg [7:0]   seg_dig     // 段选（低有效）
);

    //================ 参数定义 ================
    parameter SCAN_TIME = 50_000;   // 扫描间隔周期数

    //================ 内部信号 ================
    reg  [19:0] scan_cnt;
    wire        scan_tick = (scan_cnt == SCAN_TIME-1);
    reg  [3:0]  curr_digit;
    reg         curr_dot;

    //================ 扫描计数器 ================
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) scan_cnt <= 0;
        else scan_cnt <= scan_tick ? 0 : scan_cnt + 1;
    end

    //================ 片选扫描 ================
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) seg_sel <= 6'b111110;
        else if (scan_tick) seg_sel <= {seg_sel[4:0], seg_sel[5]};
    end

    //================ 数据选择 ================
    always @(*) 
    begin
        case (seg_sel)
            6'b111110: begin curr_digit = digit_in[3:0];  curr_dot = dot_en[0]; end
            6'b111101: begin curr_digit = digit_in[7:4];  curr_dot = dot_en[1]; end
            6'b111011: begin curr_digit = digit_in[11:8]; curr_dot = dot_en[2]; end
            6'b110111: begin curr_digit = digit_in[15:12];curr_dot = dot_en[3]; end
            6'b101111: begin curr_digit = digit_in[19:16];curr_dot = dot_en[4]; end
            6'b011111: begin curr_digit = digit_in[23:20];curr_dot = dot_en[5]; end
            default:   begin curr_digit = 4'h0;           curr_dot = 1'b0;     end
        endcase
    end

    //================ 段码生成（支持0-F）========
    always @(*) 
    begin
        if (!rst_n) begin
            seg_dig = 8'b1111_1111;  // 复位时全灭
        end
        else begin
            case (curr_digit)
                4'h0: seg_dig = {~curr_dot, 7'b1000000}; // 0
                4'h1: seg_dig = {~curr_dot, 7'b1111001}; // 1
                4'h2: seg_dig = {~curr_dot, 7'b0100100}; // 2
                4'h3: seg_dig = {~curr_dot, 7'b0110000}; // 3
                4'h4: seg_dig = {~curr_dot, 7'b0011001}; // 4
                4'h5: seg_dig = {~curr_dot, 7'b0010010}; // 5
                4'h6: seg_dig = {~curr_dot, 7'b0000010}; // 6
                4'h7: seg_dig = {~curr_dot, 7'b1111000}; // 7
                4'h8: seg_dig = {~curr_dot, 7'b0000000}; // 8
                4'h9: seg_dig = {~curr_dot, 7'b0010000}; // 9
                4'hA: seg_dig = {~curr_dot, 7'b0001000}; // A
                4'hB: seg_dig = {~curr_dot, 7'b0000011}; // b
                4'hC: seg_dig = {~curr_dot, 7'b1000110}; // C
                4'hD: seg_dig = {~curr_dot, 7'b0100001}; // d
                4'hE: seg_dig = {~curr_dot, 7'b0000110}; // E
                4'hF: seg_dig = {~curr_dot, 7'b0001110}; // F
                default: seg_dig = {1'b1, 7'b1111111};   // 其他情况全灭
            endcase
        end
    end
endmodule