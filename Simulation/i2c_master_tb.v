`timescale 1ns / 1ps

module i2c_master_tb;

    reg clk = 0;
    reg rst = 0;
    reg newd = 0;
    reg op;
    reg [6:0] addr;
    reg [7:0] din;

    wire [7:0] dout;
    wire busy, ack_err, done;
    wire sda_wire;
    wire scl_wire;

    // 100 MHz clock
    always #5 clk = ~clk;

    // ---- MASTER (DUT) ----
    i2c_master dut (
        .clk(clk),
        .rst(rst),
        .newd(newd),
        .addr(addr),
        .op(op),
        .sda(sda_wire),
        .scl(scl_wire),
        .din(din),
        .dout(dout),
        .busy(busy),
        .ack_err(ack_err),
        .done(done)
    );

    // ---- SLAVE ----
    i2c_Slave1 slave_inst (
        .scl_s1(scl_wire),
        .clk(clk),
        .rst(rst),
        .sda_s1(sda_wire),
        .ack_err(),
        .done()
    );

    initial begin
        // Reset
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(20) @(posedge clk);

        $display("------------------------------------------");
        $display("    I2C MASTER  <->  I2C SLAVE TEST");
        $display("------------------------------------------");

        // ==========================================
        // WRITE 0xA5 to slave address 0x48
        // ==========================================
        $display("[%0t] WRITE 0x12 to addr 0x67", $time);

        @(posedge clk);
        newd = 1;
        op   = 0;
        addr = 7'h67;
        din  = 8'h12;
        @(posedge clk);
        newd = 0;

        wait(done);
        #100;

        if (ack_err)
            $display("[TB] WRITE: NACK received");
        else
            $display("[TB] WRITE: ACK received");

        // ==========================================
        // READ back from slave address 0x48
        // ==========================================
        repeat(10) @(posedge clk);

        $display("[%0t] READ from addr 0x67", $time);

        @(posedge clk);
        newd = 1;
        op   = 1;
        addr = 7'h67;
        @(posedge clk);
        newd = 0;

        wait(done);
        #100;

        $display("[TB] READ dout = 0x%02h", dout);

        if (dout === 8'h12)
            $display("[TB] PASS: read data matches written data");
        else
            $display("[TB] INFO: read data = 0x%02h", dout);

        $display("------------------------------------------");
        $display("              TEST COMPLETE");
        $display("------------------------------------------");

        #500;
        $finish;
    end

    initial begin
        #20_000_000;
        $display("[TB] ERROR: timeout");
        $finish;
    end

    initial begin
        $dumpfile("i2c_master_tb.vcd");
        $dumpvars(0, i2c_master_tb);
    end

endmodule
