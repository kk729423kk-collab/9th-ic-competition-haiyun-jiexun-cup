module cangku_req_lut (
    input [4:0] addr,    // 5位地址线（可寻址32个位置）
    output reg [6:0] dout
);
// ROM内容定义
always @(*) begin
    case(addr)
        5'd0:  dout <= 7'b0000_000;
        5'd1:  dout <= 7'b0000_000;
        5'd2:  dout <= 7'b0000_000;
        5'd3:  dout <= 7'b0000_000;
        5'd4:  dout <= 7'b0000_000;
        5'd5:  dout <= 7'b0000_000;
        5'd6:  dout <= 7'b0000_000;
        5'd7:  dout <= 7'b0000_000;
        5'd8:  dout <= 7'b0000_000;
        5'd9:  dout <= 7'b0000_000;
        5'd10: dout <= 7'b0000_000;
        5'd11: dout <= 7'b0000_000;
        5'd12: dout <= {COLOR_BLACK, SHAPE_SQUARE, 2'b00, 1'b0};
        5'd13: dout <= {COLOR_BLACK, SHAPE_HEXAGON, 2'b00, 1'b0};
        5'd14: dout <= {COLOR_BLACK, SHAPE_CIRCLE, 2'b00, 1'b0};
        5'd15: dout <= {COLOR_BLACK, SHAPE_IRREGULAR, 2'b00, 1'b0};
        5'd16: dout <= {COLOR_BLUE, SHAPE_SQUARE, 2'b00, 1'b1};
        5'd17: dout <= {COLOR_BLUE, SHAPE_HEXAGON, 2'b00, 1'b1};
        5'd18: dout <= {COLOR_BLUE, SHAPE_CIRCLE, 2'b00, 1'b1};
        5'd19: dout <= {COLOR_BLUE, SHAPE_IRREGULAR, 2'b00, 1'b1};
        default: dout <= 7'b0000_000;
    endcase
end

endmodule