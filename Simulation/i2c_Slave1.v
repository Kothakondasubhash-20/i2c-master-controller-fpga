`timescale 1ns / 1ps

module i2c_Slave1(
    input  scl_s1,
    input  clk,
    input  rst,
    inout  sda_s1,
    output reg ack_err,
    output reg done
    );

    // State encoding
    parameter idle        = 4'd0;
    parameter read_addr   = 4'd1;
    parameter send_ack1   = 4'd2;
    parameter send_data   = 4'd3;
    parameter master_ack  = 4'd4;
    parameter read_data   = 4'd5;
    parameter send_ack2   = 4'd6;
    parameter wait_p      = 4'd7;
    parameter detect_stop = 4'd8;

    reg [3:0] state = idle;

    // Memory
    reg [7:0] mem [0:127];
    reg [7:0] r_addr;
    reg [6:0] addr;
    reg       r_mem;
    reg       w_mem;
    reg [7:0] dout;
    reg [7:0] din;
    reg       sda_t;
    reg       sda_en;
    reg [3:0] bitcnt;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 128; i = i + 1)
                mem[i] <= i;
            dout <= 8'h00;
        end
        else if (r_mem == 1'b1) begin
            dout <= mem[addr];
        end
        else if (w_mem == 1'b1) begin
            mem[addr] <= din;
        end
    end

    // ---- Clock parameters (FIXED: 100 MHz) ----
    parameter sys_freq   = 100_000_000;
    parameter i2c_freq   = 100_000;

    parameter clk_count4 = sys_freq / i2c_freq;   // 1000
    parameter clk_count1 = clk_count4 / 4;        // 250

    // Sample point in the middle of the SCL-high window
    localparam integer SAMPLE_PT = clk_count1 * 2 + clk_count1 / 2;  // 625

    integer count1 = 0;
    reg [1:0] pulse = 0;
    reg busy;

    always @(posedge clk) begin
        if (rst) begin
            pulse  <= 0;
            count1 <= 0;
        end
        else if (busy == 1'b0) begin
            pulse  <= 2;
            count1 <= SAMPLE_PT;
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

    // START detection
    reg scl_t;
    wire start;
    always @(posedge clk) scl_t <= scl_s1;
    assign start = (~scl_s1) & scl_t;

    reg r_ack;

    always @(posedge clk) begin
        if (rst) begin
            bitcnt  <= 0;
            state   <= idle;
            r_addr  <= 7'b0000000;
            sda_en  <= 1'b0;
            sda_t   <= 1'b0;
            addr    <= 0;
            r_mem   <= 0;
            din     <= 8'h00;
            ack_err <= 0;
            done    <= 1'b0;
            busy    <= 1'b0;
        end
        else begin
            case (state)
                idle: begin
                    if (scl_s1 == 1'b1 && sda_s1 == 1'b0) begin
                        busy  <= 1'b1;
                        state <= wait_p;
                    end
                    else begin
                        state <= idle;
                    end
                end

                wait_p: begin
                    // FIXED: was count1 == 399
                    if (pulse == 2'b11 && count1 == clk_count1 * 4 - 1)
                        state <= read_addr;
                    else
                        state <= wait_p;
                end

                read_addr: begin
                    sda_en <= 1'b0;
                    if (bitcnt <= 7) begin
                        case (pulse)
                            // FIXED: was count1 == 200
                            2: if (count1 == SAMPLE_PT)
                                   r_addr <= {r_addr[6:0], sda_s1};
                            default: ;
                        endcase
                        if (count1 == clk_count1 * 4 - 1) begin
                            bitcnt <= bitcnt + 1;
                        end
                    end
                    else begin
                        state  <= send_ack1;
                        bitcnt <= 0;
                        sda_en <= 1'b1;
                        addr   <= r_addr[7:1];
                    end
                end

                send_ack1: begin
                    case (pulse)
                        0: sda_t <= 1'b0;
                        default: ;
                    endcase
                    if (count1 == clk_count1 * 4 - 1) begin
                        if (r_addr[0] == 1'b1) begin
                            state <= send_data;
                            r_mem <= 1'b1;
                        end
                        else begin
                            state <= read_data;
                            r_mem <= 1'b0;
                        end
                    end
                end

                read_data: begin
                    sda_en <= 1'b0;
                    if (bitcnt <= 7) begin
                        case (pulse)
                            // FIXED: was count1 == 200
                            2: if (count1 == SAMPLE_PT)
                                   din <= {din[6:0], sda_s1};
                            default: ;
                        endcase
                        if (count1 == clk_count1 * 4 - 1)
                            bitcnt <= bitcnt + 1;
                    end
                    else begin
                        state  <= send_ack2;
                        bitcnt <= 0;
                        sda_en <= 1'b1;
                        w_mem  <= 1'b1;
                    end
                end

                send_ack2: begin
                    case (pulse)
                        0: sda_t <= 1'b0;
                        1: w_mem <= 1'b0;
                        default: ;
                    endcase
                    if (count1 == clk_count1 * 4 - 1) begin
                        state  <= detect_stop;
                        sda_en <= 1'b0;
                    end
                end

                send_data: begin
                    sda_en <= 1'b1;
                    if (bitcnt <= 7) begin
                        r_mem <= 1'b0;
                        case (pulse)
                            // FIXED: was count1 == 100
                            1: if (count1 == clk_count1)
                                   sda_t <= dout[7 - bitcnt];
                            default: ;
                        endcase
                        if (count1 == clk_count1 * 4 - 1)
                            bitcnt <= bitcnt + 1;
                    end
                    else begin
                        state  <= master_ack;
                        bitcnt <= 0;
                        sda_en <= 1'b0;
                    end
                end

                master_ack: begin
                    case (pulse)
                        // FIXED: was count1 == 200
                        2: if (count1 == SAMPLE_PT)
                               r_ack <= sda_s1;
                        default: ;
                    endcase
                    if (count1 == clk_count1 * 4 - 1) begin
                        if (r_ack == 1'b1) begin
                            ack_err <= 1'b0;
                            state   <= detect_stop;
                            sda_en  <= 1'b0;
                        end
                        else begin
                            ack_err <= 1'b1;
                            state   <= detect_stop;
                            sda_en  <= 1'b0;
                        end
                    end
                end

                detect_stop: begin
                    // FIXED: was count1 == 399
                    if (pulse == 2'b11 && count1 == clk_count1 * 4 - 1) begin
                        state <= idle;
                        busy  <= 1'b0;
                        done  <= 1'b1;
                    end
                    else begin
                        state <= detect_stop;
                    end
                end

                default: state <= idle;
            endcase
        end
    end

    assign sda_s1 = (sda_en == 1'b1) ? sda_t : 1'bz;

endmodule
