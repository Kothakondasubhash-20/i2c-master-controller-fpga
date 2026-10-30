`timescale 1ns / 1ps

module i2c_master(
    input        clk,
    input        rst,
    input        newd,
    input  [6:0] addr,
    input        op,
    inout        sda,
    output       scl,
    input  [7:0] din,
    output [7:0] dout,
    output reg   busy,
    output reg   ack_err,
    output reg   done
    );

    parameter sys_freq = 100_000_000;
    parameter i2c_freq = 100_000;

    parameter clk_count4 = sys_freq / i2c_freq;  // 1000
    parameter clk_count1 = clk_count4 / 4;       // 250

    reg scl_t;
    reg sda_t;
    reg sda_en;

    integer count1;
    reg [1:0] pulse;
    reg [3:0] bitcount;
    reg [7:0] data_addr;
    reg [7:0] data_tx;
    reg [7:0] rx_data;
    reg       r_ack;

    parameter IDLE       = 4'd0,
              START      = 4'd1,
              WRITE_ADDR = 4'd2,
              ACK_1      = 4'd3,
              WRITE_DATA = 4'd4,
              READ_DATA  = 4'd5,
              STOP       = 4'd6,
              ACK_2      = 4'd7,
              MASTER_ACK = 4'd8;

    reg [3:0] state;

    initial begin
        state    = IDLE;
        scl_t    = 1'b1;
        sda_t    = 1'b1;
        sda_en   = 1'b0;
        bitcount = 4'd0;
        count1   = 0;
        pulse    = 2'b00;
        busy     = 1'b0;
        ack_err  = 1'b0;
        done     = 1'b0;
        rx_data  = 8'h00;
    end

    always @(posedge clk) begin
        if (rst) begin
            pulse  <= 0;
            count1 <= 0;
        end
        else if (busy == 1'b0) begin
            pulse  <= 0;
            count1 <= 0;
        end
        else if (count1 == clk_count1 - 1) begin
            pulse  <= 1;
            count1 <= count1 + 1;
        end
        else if (count1 == clk_count1 * 2 - 1) begin
            pulse  <= 2;
            count1 <= count1 + 1;
        end
        else if (count1 == clk_count1 * 3 - 1) begin
            pulse  <= 3;
            count1 <= count1 + 1;
        end
        else if (count1 == clk_count1 * 4 - 1) begin
            pulse  <= 0;
            count1 <= 0;
        end
        else begin
            count1 <= count1 + 1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            bitcount  <= 0;
            data_addr <= 0;
            data_tx   <= 0;
            scl_t     <= 1;
            sda_t     <= 1;
            state     <= IDLE;
            busy      <= 1'b0;
            ack_err   <= 1'b0;
            done      <= 1'b0;
            sda_en    <= 1'b0;
            rx_data   <= 8'h00;
        end
        else begin
            case (state)

                IDLE: begin
                    done <= 1'b0;
                    if (newd == 1'b1) begin
                        data_addr <= {addr, op};
                        data_tx   <= din;
                        busy      <= 1'b1;
                        state     <= START;
                        ack_err   <= 1'b0;
                        rx_data   <= 8'h00;
                    end
                    else begin
                        data_addr <= 0;
                        data_tx   <= 0;
                        busy      <= 1'b0;
                        state     <= IDLE;
                        ack_err   <= 1'b0;
                    end
                end

                START: begin
                    sda_en <= 1'b1;
                    case (pulse)
                        0: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                        1: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                        2: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                        3: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                    endcase
                    if (count1 == clk_count1 * 4 - 1) begin
                        state <= WRITE_ADDR;
                        scl_t <= 1'b0;
                    end
                end

                WRITE_ADDR: begin
                    sda_en <= 1'b1;
                    if (bitcount <= 7) begin
                        case (pulse)
                            0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                            1: begin scl_t <= 1'b0; sda_t <= data_addr[7 - bitcount]; end
                            2: begin scl_t <= 1'b1; end
                            3: begin scl_t <= 1'b1; end
                        endcase
                        if (count1 == clk_count1 * 4 - 1) begin
                            scl_t    <= 1'b0;
                            bitcount <= bitcount + 1;
                        end
                    end
                    else begin
                        state    <= ACK_1;
                        bitcount <= 0;
                        sda_en   <= 1'b0;
                    end
                end

                ACK_1: begin
                    sda_en <= 1'b0;
                    case (pulse)
                        0, 1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                        2:    begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= sda; end
                        3:    begin scl_t <= 1'b1; end
                    endcase
                    if (count1 == clk_count1 * 4 - 1) begin
                        if (r_ack == 1'b0 && data_addr[0] == 1'b0) begin
                            state    <= WRITE_DATA;
                            sda_t    <= 1'b0;
                            sda_en   <= 1'b1;
                            bitcount <= 0;
                        end
                        else if (r_ack == 1'b0 && data_addr[0] == 1'b1) begin
                            state    <= READ_DATA;
                            sda_t    <= 1'b1;
                            sda_en   <= 1'b0;
                            bitcount <= 0;
                        end
                        else begin
                            state   <= STOP;
                            sda_en  <= 1'b1;
                            ack_err <= 1'b1;
                        end
                    end
                end

                WRITE_DATA: begin
                    if (bitcount <= 7) begin
                        case (pulse)
                            0: begin scl_t <= 1'b0; end
                            1: begin scl_t <= 1'b0; sda_en <= 1'b1; sda_t <= data_tx[7 - bitcount]; end
                            2: begin scl_t <= 1'b1; end
                            3: begin scl_t <= 1'b1; end
                        endcase
                        if (count1 == clk_count1 * 4 - 1) begin
                            scl_t    <= 1'b0;
                            bitcount <= bitcount + 1;
                        end
                    end
                    else begin
                        state    <= ACK_2;
                        bitcount <= 0;
                        sda_en   <= 1'b0;
                    end
                end

                READ_DATA: begin
                    sda_en <= 1'b0;
                    if (bitcount <= 7) begin
                        case (pulse)
                            0, 1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                            2: begin
                                scl_t <= 1'b1;
                                if (count1 == clk_count1 * 2 + clk_count1 / 2)
                                    rx_data <= {rx_data[6:0], sda};
                            end
                            3: begin scl_t <= 1'b1; end
                        endcase
                        if (count1 == clk_count1 * 4 - 1) begin
                            scl_t    <= 1'b0;
                            bitcount <= bitcount + 1;
                        end
                    end
                    else begin
                        state    <= MASTER_ACK;
                        bitcount <= 0;
                        sda_en   <= 1'b1;
                    end
                end

                MASTER_ACK: begin
                    sda_en <= 1'b1;
                    case (pulse)
                        0, 1, 2, 3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                    endcase
                    if (count1 == clk_count1 * 4 - 1) begin
                        sda_t  <= 1'b0;
                        state  <= STOP;
                        sda_en <= 1'b1;
                    end
                end

                ACK_2: begin
                    sda_en <= 1'b0;
                    case (pulse)
                        0, 1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                        2:    begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= sda; end
                        3:    begin scl_t <= 1'b1; end
                    endcase
                    if (count1 == clk_count1 * 4 - 1) begin
                        sda_t  <= 1'b0;
                        sda_en <= 1'b1;
                        state  <= STOP;
                        if (r_ack == 1'b0)
                            ack_err <= 1'b0;
                        else
                            ack_err <= 1'b1;
                    end
                end

                STOP: begin
                    sda_en <= 1'b1;
                    case (pulse)
                        0, 1: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                        2, 3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                    endcase
                    if (count1 == clk_count1 * 4 - 1) begin
                        state  <= IDLE;
                        scl_t  <= 1'b0;
                        busy   <= 1'b0;
                        sda_en <= 1'b1;
                        done   <= 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign sda  = (sda_en == 1) ? ((sda_t == 0) ? 1'b0 : 1'b1) : 1'bz;
    assign scl  = scl_t;
    assign dout = rx_data;

endmodule
