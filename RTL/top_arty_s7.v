`timescale 1ns / 1ps

module top_arty_s7 (
    input  wire clk,       // 100 MHz (pin E3)
    input  wire rst_btn,   // Button (pin C18), active-high press
    inout  wire sda,       // I2C SDA (pin J13)
    output wire scl,       // I2C SCL (pin J14)
    output wire led0,      // Activity LED
    output wire led1       // Error LED
    );

    wire rst;
    assign rst = rst_btn;

    wire [7:0] dout;
    wire busy, ack_err, done;

    // -------- I2C Master --------
    i2c_master i2c_inst (
        .clk(clk),
        .rst(rst),
        .newd(1'b1),       // keep triggering continuously for demo
        .addr(7'h48),
        .op(1'b1),         // 1 = read
        .sda(sda),
        .scl(scl),
        .din(8'h00),
        .dout(dout),
        .busy(busy),
        .ack_err(ack_err),
        .done(done)
    );

    assign led0 = busy;
    assign led1 = ack_err;

endmodule
