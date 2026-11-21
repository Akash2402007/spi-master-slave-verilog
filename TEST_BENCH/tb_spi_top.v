`timescale 1ns / 1ps

module tb_spi_top;

    // =========================================================
    // PARAMETERS
    // =========================================================

    parameter SPI_MODE = 0;
    parameter CLKS_PER_HALF_BIT = 2;


    // =========================================================
    // TESTBENCH SIGNALS
    // =========================================================

    reg system_clk;
    reg rst;

    reg        tx_start;

    reg [7:0]  master_tx_byte;
    reg [7:0]  slave_tx_byte;

    wire       master_tx_ready;
    wire       master_rx_signal;
    wire [7:0] master_rx_byte;

    wire [7:0] slave_rx_byte;
    wire       slave_rx_dv;


    // =========================================================
    // DUT
    // =========================================================

    spi_top #(
        .SPI_MODE(SPI_MODE),
        .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
    )
    dut (
        .system_clk(system_clk),
        .rst(rst),

        .tx_start(tx_start),

        .master_tx_byte(master_tx_byte),
        .slave_tx_byte(slave_tx_byte),

        .master_tx_ready(master_tx_ready),
        .master_rx_signal(master_rx_signal),
        .master_rx_byte(master_rx_byte),

        .slave_rx_byte(slave_rx_byte),
        .slave_rx_dv(slave_rx_dv)
    );


    // =========================================================
    // SYSTEM CLOCK
    // =========================================================

    initial begin
        system_clk = 1'b0;

        forever begin
            #5 system_clk = ~system_clk;
        end
    end


    // =========================================================
    // TEST SEQUENCE
    // =========================================================

    initial begin

        // Initial values
        rst            = 1'b0;
        tx_start       = 1'b0;

        master_tx_byte = 8'h00;
        slave_tx_byte  = 8'h00;


        // Apply reset
        #50;

        rst = 1'b1;


        // Wait for system clock
        @(posedge system_clk);


        // Wait until master is ready
        wait(master_tx_ready == 1'b1);


        // Load data
        master_tx_byte = 8'hA5;
        slave_tx_byte  = 8'h3C;


        // Start transaction
        // MODIFIED: Drive inputs on negative clock edges

        @(negedge system_clk);

        tx_start = 1'b1;

        @(negedge system_clk);

        tx_start = 1'b0;


        // Wait for transaction to finish
        wait(master_rx_signal == 1'b1);


        // =====================================================
        // DISPLAY RESULTS
        // =====================================================

        $display("============================================");
        $display("             SPI TEST RESULT");
        $display("============================================");

        $display("SPI MODE       = %0d", SPI_MODE);
        $display("MASTER TX      = %h", master_tx_byte);
        $display("SLAVE  TX      = %h", slave_tx_byte);

        $display("--------------------------------------------");

        $display("MASTER RX      = %h", master_rx_byte);
        $display("SLAVE  RX      = %h", slave_rx_byte);

        $display("--------------------------------------------");


        // =====================================================
        // CHECK MASTER RX
        // =====================================================

        if(master_rx_byte == slave_tx_byte)
            $display("MASTER RX TEST : PASS");
        else
            $display("MASTER RX TEST : FAIL");


        // =====================================================
        // CHECK SLAVE RX
        // =====================================================

        if(slave_rx_byte == master_tx_byte)
            $display("SLAVE RX TEST  : PASS");
        else
            $display("SLAVE RX TEST  : FAIL");


        $display("============================================");


        #100;

        $finish;

    end

endmodule
