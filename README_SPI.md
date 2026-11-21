# Configurable SPI Master-Slave Communication Controller Using Verilog HDL

## Overview

This project implements a **full-duplex SPI (Serial Peripheral Interface) master-slave controller** using Verilog HDL. The master and slave are integrated through a top-level module and communicate over the SPI signals: `SPI_CLK`, `SPI_MOSI`, `SPI_MISO`, and `SPI_CS`.

The design uses configurable `SPI_MODE` and `CLKS_PER_HALF_BIT` parameters. The SPI mode setting selects the clock polarity (CPOL) and clock phase (CPHA), while the clock-divider parameter controls the SPI clock rate relative to the system clock.

The supplied testbench applies a transfer in which the master sends `8'hA5` and the slave sends `8'h3C`. The testbench checks the received bytes in both directions.

## Features

- Full-duplex communication between an SPI master and an SPI slave.
- Configurable SPI modes 0, 1, 2, and 3 through the `SPI_MODE` parameter.
- CPOL- and CPHA-dependent clocking, sampling, and data-shifting logic.
- Parameterized SPI clock generation using `CLKS_PER_HALF_BIT`.
- MSB-first, 8-bit data transfer.
- Separate master and slave finite state machine (FSM) logic.
- MOSI and MISO data paths for simultaneous transmission and reception.
- Active-low chip-select signal (`SPI_CS`).
- Synchronous SPI-clock edge detection in the slave using the shared `system_clk` domain.
- Verilog testbench for exercising a master-slave data exchange.

## SPI Modes

The `SPI_MODE` parameter determines CPOL and CPHA:

| SPI mode | CPOL | CPHA | SCLK idle level | Sampling edge | Data-change edge |
|---|---:|---:|---|---|---|
| Mode 0 | 0 | 0 | Low | First (leading) edge | Second (trailing) edge |
| Mode 1 | 0 | 1 | Low | Second (trailing) edge | First (leading) edge |
| Mode 2 | 1 | 0 | High | First (leading) edge | Second (trailing) edge |
| Mode 3 | 1 | 1 | High | Second (trailing) edge | First (leading) edge |

Set `SPI_MODE` to `0`, `1`, `2`, or `3` in the top-level/testbench parameter configuration to select the mode being simulated.

## Project Structure

A recommended repository layout is:

```text
spi-master-slave-verilog/
│
├── README.md
│
├── RTL/
│   ├── spi_top.v
│   ├── spi_master.v
│   └── spi_slave.v
│
├── Testbench/
│   └── tb_spi_top.v
│
└── Simulation/
    └── spi_simulation.png       # Add a waveform screenshot, if available
```

The `Simulation` directory is optional. Add a waveform screenshot only after capturing it from your own simulation.

## Module Description

### 1. `spi_master.v`

Implements the SPI master controller.

Main responsibilities:

- Accepts an 8-bit transmit byte and a `tx_start` request.
- Generates the SPI clock according to `SPI_MODE` and `CLKS_PER_HALF_BIT`.
- Controls the active-low chip-select signal.
- Transmits data on MOSI, MSB first.
- Samples incoming MISO data on the edge selected by CPOL and CPHA.
- Uses an FSM with `idle`, `transfer`, and `clean_up` states.
- Raises `tx_ready` when it is ready for another transfer and pulses `rx_signal` when a received byte is available.

### 2. `spi_slave.v`

Implements the SPI slave controller.

Main responsibilities:

- Loads `Slave_TX_Byte` for transmission to the master.
- Receives master data from MOSI, MSB first.
- Drives MISO according to the selected SPI mode.
- Uses CPOL- and CPHA-dependent sample and shift edges.
- Detects SPI clock transitions synchronously with `system_clk` using a delayed SPI-clock register.
- Updates `Slave_RX_Byte` after receiving a byte and asserts `Slave_RX_DV` to indicate that the received byte is valid.

### 3. `spi_top.v`

Connects the master and slave modules and wires their SPI signals together:

- `SPI_CLK`
- `SPI_MOSI`
- `SPI_MISO`
- `SPI_CS`

### 4. `tb_spi_top.v`

Provides the simulation environment:

- Generates the system clock.
- Applies reset.
- Supplies transmit data to the master and slave.
- Starts the SPI transaction.
- Displays the transmitted and received bytes.
- Compares the received bytes against the expected values.

## Parameters

| Parameter | Default value | Description |
|---|---:|---|
| `SPI_MODE` | `0` | Selects SPI mode 0, 1, 2, or 3. |
| `CLKS_PER_HALF_BIT` | `2` | Number of system-clock cycles used for each SPI clock half-period. |

The SPI clock frequency is determined by the system clock and the half-period divider:

\[
f_{SCLK} = \frac{f_{system\_clk}}{2 \times CLKS\_PER\_HALF\_BIT}
\]

For example, with `CLKS_PER_HALF_BIT = 2`, the SPI clock completes one full period in four system-clock cycles.

## Testbench Scenario

The supplied testbench uses the following default values:

```verilog
parameter SPI_MODE = 0;
parameter CLKS_PER_HALF_BIT = 2;

master_tx_byte = 8'hA5;
slave_tx_byte  = 8'h3C;
```

During the full-duplex transfer:

- The master sends `8'hA5` to the slave.
- The slave sends `8'h3C` to the master.

Expected received values:

| Signal | Expected value |
|---|---|
| `master_rx_byte` | `8'h3C` |
| `slave_rx_byte` | `8'hA5` |

The testbench prints `PASS` or `FAIL` for each receive-side comparison. Run and inspect the simulation for each SPI mode before claiming that all four modes have been verified.

## Simulation Using Xilinx Vivado

1. Create or open a Vivado RTL project.
2. Add `spi_master.v`, `spi_slave.v`, and `spi_top.v` under **Design Sources**.
3. Add `tb_spi_top.v` under **Simulation Sources**.
4. Set `tb_spi_top` as the simulation top module.
5. Select the required `SPI_MODE` value in the testbench.
6. Run **Run Behavioral Simulation**.
7. Inspect `SPI_CLK`, `SPI_CS`, `SPI_MOSI`, `SPI_MISO`, `master_rx_byte`, and `slave_rx_byte` in the waveform.
8. Check the Tcl Console for the testbench PASS/FAIL messages.

To test another SPI mode, change the testbench parameter and rerun the simulation. Record the result for each mode separately.

## Tools and Concepts

- **Hardware description language:** Verilog HDL
- **Simulation tool:** Xilinx Vivado (the project was developed using Vivado 2018.2)
- **Digital design concepts:** RTL design, finite state machines, shift registers, parameterized design, clock division, clock-edge detection, and serial communication
- **Protocol:** SPI, full-duplex, 8-bit, MSB-first transfer

## Implementation Notes and Limitations

- The current top-level design connects the master and slave using the same `system_clk` domain. The slave uses synchronous edge detection for the internally generated `SPI_CLK`; this should not be described as a complete asynchronous clock-domain-crossing solution for an independently clocked external SPI interface.
- The testbench is configured for one SPI mode at a time. Each mode should be simulated and checked independently.
- The supplied testbench checks one data pattern (`A5` from the master and `3C` from the slave). Additional patterns, back-to-back transfers, reset-during-transfer behaviour, and other corner cases can be added for more complete verification.
- Simulation results should be reported only for the modes and test cases that have actually been run.

## Possible Future Improvements

- Add automated tests for all four SPI modes.
- Test multiple data patterns and consecutive transfers.
- Add configurable data width and bit-order options.
- Add assertions and stronger self-checking verification.
- Add checks for reset during an active transfer and chip-select timing.
- Evaluate timing and resource utilisation after FPGA synthesis.

---

## Author

**Akash Singh Anand**

Verilog HDL | RTL Design | SPI Protocol | FPGA Design and Verification
