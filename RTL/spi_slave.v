`timescale 1ns / 1ps 

module spi_slave #( 
  parameter SPI_MODE = 0 
)( 
    input system_clk, 
    input rst, 

    input wire SPI_CLK, 
    output reg SPI_MISO, 
    input wire SPI_MOSI, 
    input wire SPI_CS, 

    input wire [7:0] Slave_TX_Byte, 
    output reg [7:0] Slave_RX_Byte, 
    output reg Slave_RX_DV 

    ); 


    // Mode 0 : CPOL = 0, CPHA = 0 
    // Mode 1 : CPOL = 0, CPHA = 1 
    // Mode 2 : CPOL = 1, CPHA = 0 
    // Mode 3 : CPOL = 1, CPHA = 1 


    wire w_CPOL = (SPI_MODE == 2) || (SPI_MODE == 3); 
    wire w_CPHA = (SPI_MODE == 1) || (SPI_MODE == 3); 


        // SCLK edge detection
        // MODIFIED: Master and slave share system_clk
        reg r_SPI_CLK_d;

        always @(posedge system_clk or negedge rst) begin
          if(!rst)
             r_SPI_CLK_d <= w_CPOL;
          else
             r_SPI_CLK_d <= SPI_CLK;
        end

        wire w_SCLK_Rising =
             (SPI_CLK == 1'b1) && (r_SPI_CLK_d == 1'b0);

        wire w_SCLK_Falling =
             (SPI_CLK == 1'b0) && (r_SPI_CLK_d == 1'b1);

        // MODE-DEPENDENT SAMPLE / SHIFT EDGES 
        // CPOL=0: 
        //     rising = first edge 
        //     falling = second edge 
        // 
        // CPOL=1: 
        //     falling = first edge 
        //     rising = second edge 

        wire w_First_Edge = (w_CPOL == 1'b0) ? w_SCLK_Rising : w_SCLK_Falling; 
        wire w_Second_Edge = (w_CPOL == 1'b0) ? w_SCLK_Falling : w_SCLK_Rising; 

        // SAMPLE AND SHIFT EDGES 
        // CPHA = 0: 
        //     Sample on first edge 
        //     Change MISO on second edge 
        // 
        // CPHA = 1: 
        //     Change MISO on first edge 
        //     Sample on second edge 

        wire w_Sample_Edge = (w_CPHA == 1'b0) ? w_First_Edge : w_Second_Edge; 
        wire w_Shift_Edge = (w_CPHA == 1'b0) ? w_Second_Edge : w_First_Edge; 

        reg [2:0] r_Bit_Index; 
        reg [7:0] r_RX_Byte; 
        reg [7:0] r_TX_Byte; 

        reg r_active; 

        always @(posedge system_clk or negedge rst)  begin 
           if(!rst)   begin 
           /* 
             r_Bit_Index  <=  3'b111; 
             SPI_MISO <= 1'b0; 
             Slave_RX_DV <= 1'b0; 
             Slave_RX_Byte <= 8'h00; 
            */ 
              r_Bit_Index <= 3'b111; 
              r_RX_Byte <= 8'h00; 
              r_TX_Byte <= 8'h00; 

              SPI_MISO <= w_CPOL; 
              Slave_RX_Byte <= 8'h00; 
              Slave_RX_DV <= 1'b0; 

              r_active <= 1'b0; 
           end  

           /*   
           else if(SPI_CS) begin   // inactive CS 

              r_Bit_Index   <= 3'b111; 
              Slave_RX_DV <= 1'b0; 
              r_TX_Byte  <= Slave_TX_Byte; 
              SPI_MISO  <= Slave_TX_Byte[7]; // Pre-load MSB; 
           end  else begin  
              Slave_RX_DV <= 1'b0; 
              // sample MOSI on rising edge 
              if(w_SCLK_Rising)  begin 
                 r_RX_Byte[r_Bit_Index] <= SPI_MOSI; 
              end 

              // shift MISO on falling edge 
              if(w_SCLK_Falling) begin 
                if(r_Bit_Index == 0) begin 
                  r_Bit_Index <= 3'b111; 
                  Slave_RX_Byte <= r_RX_Byte; 
                  Slave_RX_DV <= 1'b1; 
                end   else begin 
                  r_Bit_Index <= r_Bit_Index - 1'b1; 
                end 
                SPI_MISO <= r_TX_Byte[r_Bit_Index - 1'b1]; 
              end    
              */ 

            else  begin 
              Slave_RX_DV <= 1'b0; 

              //  inactive CS 
              if(SPI_CS)  begin 
                 r_active <= 1'b0; 
                 r_Bit_Index <= 3'b111; 
                 r_RX_Byte <= 8'h00; 

                 // load byte to transmit 
                 r_TX_Byte <= Slave_TX_Byte; 

                 // ------------------------------------------------ 
                 // CPHA = 0 
                 // 
                 // First bit must already be present before the 
                 // first SPI clock edge. 
                 // ------------------------------------------------ 
                 if(w_CPHA == 1'b0)  begin 
                    SPI_MISO <= Slave_TX_Byte[7]; 
                 end 

                 else begin 
                    // CPHA = 1 means data changes on first edge. 
                    // Therefore MISO starts at the idle level. 
                    SPI_MISO <= w_CPOL; 
                 end 
              end 

              //  Active CS 
              else begin 

                 r_active <= 1'b1; 

                 // =================================================
                 // SAMPLE MOSI
                 // =================================================
                 if(w_Sample_Edge)  begin 

                    // Store the received bit
                    r_RX_Byte[r_Bit_Index] <= SPI_MOSI; 

                    // We decreament after each Sample Edge
                    // after bit 0 has been sampled the byte is complete
                    if(r_Bit_Index == 3'b000) begin 

                       // complete byte received
                       // Include the current SPI_MOSI bit because
                       // r_RX_Byte has not updated yet due to
                       // non-blocking assignment.
                       Slave_RX_Byte <= {r_RX_Byte[7:1], SPI_MOSI}; 
                       Slave_RX_DV <= 1'b1; 
                       r_Bit_Index <= 3'b111; 
                    end 

                    else begin 
                       r_Bit_Index <= r_Bit_Index - 1'b1; 
                    end 

                 end 


                 // =================================================
                 // SHIFT / CHANGE MISO
                 // =================================================
                 if(w_Shift_Edge) begin 

                    // CPHA = 1 
                    // On the first edge, output the first bit. 
                    // after that output the next bit 
                    if(w_CPHA == 1'b1) begin

                        // First transmitted bit
                        if(r_Bit_Index == 3'b111) begin 
                            SPI_MISO <= r_TX_Byte[7]; 
                        end 

                        else begin 
                            SPI_MISO <= r_TX_Byte[r_Bit_Index]; 
                        end

                    end 

                    else begin

                        // CPHA = 0 
                        // 
                        // First bit was already preloaded. 
                        // After each sample, move to the next bit. 

                        if(r_Bit_Index != 3'b000) begin 
                           SPI_MISO <= r_TX_Byte[r_Bit_Index]; 
                        end

                    end

                 end 

              end 

            end 

        end 


endmodule
