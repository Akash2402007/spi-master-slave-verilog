`timescale 1ns / 1ps

module spi_top #(
    parameter SPI_MODE = 0,
    parameter CLKS_PER_HALF_BIT = 2
)(
    input  wire       system_clk,
    input  wire       rst,

    // Master control
    input  wire       tx_start,

    // Data sent by Master
    input  wire [7:0] master_tx_byte,

    // Data sent by Slave
    input  wire [7:0] slave_tx_byte,

    // Master status/data
    output wire       master_tx_ready,
    output wire       master_rx_signal,
    output wire [7:0] master_rx_byte,

    // Slave status/data
    output wire [7:0] slave_rx_byte,
    output wire       slave_rx_dv
);

    // =========================================================
    // Internal SPI bus
    // =========================================================

    wire SPI_CLK;
    wire SPI_MOSI;
    wire SPI_MISO;
    wire SPI_CS;


    // =========================================================
    // SPI MASTER
    // =========================================================

    spi_master #(
        .SPI_MODE(SPI_MODE),
        .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
    )
    u_spi_master (
        .system_clk(system_clk),
        .rst(rst),

        .tx_byte(master_tx_byte),
        .tx_start(tx_start),

        .tx_ready(master_tx_ready),
        .rx_signal(master_rx_signal),
        .rx_byte(master_rx_byte),

        .SPI_CLK(SPI_CLK),
        .SPI_MISO(SPI_MISO),
        .SPI_MOSI(SPI_MOSI),
        .SPI_CS(SPI_CS)
    );


    // =========================================================
    // SPI SLAVE
    // =========================================================

    spi_slave #(
        .SPI_MODE(SPI_MODE)
    )
    u_spi_slave (
        .system_clk(system_clk),
        .rst(rst),

        .SPI_CLK(SPI_CLK),
        .SPI_MISO(SPI_MISO),
        .SPI_MOSI(SPI_MOSI),
        .SPI_CS(SPI_CS),

        .Slave_TX_Byte(slave_tx_byte),
        .Slave_RX_Byte(slave_rx_byte),
        .Slave_RX_DV(slave_rx_dv)
    );

endmodule