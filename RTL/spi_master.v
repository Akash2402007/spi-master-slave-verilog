`timescale 1ns / 1ps 

module spi_master #( 
   parameter SPI_MODE = 0,  // modes : 0,1,2,3 
   parameter CLKS_PER_HALF_BIT = 2 
)( 
    input system_clk,      //   system clock 
    input rst,        //   reset signal (active-low) 
    input wire [7:0] tx_byte,      //  data byte to be send over MOSI 
    input tx_start,   //  high when transmission of data starts 
    output reg tx_ready,  //  high when ready for new byte  
    output reg rx_signal,  // high when received data from MISO 
    output reg [7:0] rx_byte,   //  data byte received from MISO 

    // MODIFIED: Changed output reg to output wire
    output wire SPI_CLK,     // SCLK 
    input wire SPI_MISO,    // MISO line 
    output reg SPI_MOSI,    // MOSI line 
    output reg SPI_CS       // chip select line (active - low) 

    ); 

    localparam idle = 2'b00; 
    localparam transfer = 2'b01; 
    localparam clean_up = 2'b10; 

    wire w_CPOL = (SPI_MODE == 2) || (SPI_MODE == 3); 
    wire w_CPHA = (SPI_MODE == 1) || (SPI_MODE == 3); 

    reg [1:0] r_SM_State;    //  keeps the record of the current state 
    reg [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_Clk_Count;   // when should SCLK change  
      // 1SCLK  = 4 system_clk   half bit require 2 system clocks  so *2 in the end 
    reg [2:0] r_Bit_Count;  //  denotes the current SPI bit 
    reg [7:0] r_TX_Shift;   //  what is been sent 
    reg [7:0] r_RX_Shift;   //  what is received 

    wire w_Leading_Edge; 
    wire w_Trailing_Edge; 

    // SCLK edge detection generation 
    reg r_SPI_CLK; 
    reg r_PREV_SPI_CLK; 

    // MODIFIED: External SPI clock directly follows internal SPI clock
    assign SPI_CLK = r_SPI_CLK;

    always @(posedge system_clk or negedge rst) 
    begin 
       if(!rst) 
       begin 
          r_Clk_Count <= 0; 
          r_SPI_CLK <= w_CPOL; 
       end 
       else if(r_SM_State == transfer) 
       begin 
          if(r_Clk_Count == (CLKS_PER_HALF_BIT -1)) 
          begin 
             r_Clk_Count <= 0; 
             r_SPI_CLK <= ~r_SPI_CLK; 
          end 
          else 
          begin 
             r_Clk_Count <= r_Clk_Count + 1'b1; 
          end 
       end 
       else 
       begin 
          r_Clk_Count <= 0; 
          r_SPI_CLK <= w_CPOL; 
       end 
    end 

    always @(posedge system_clk or negedge rst) 
    begin 
       if(!rst) 
       begin 
          r_PREV_SPI_CLK <= w_CPOL; 
       end 
       else 
       begin 
          r_PREV_SPI_CLK <= r_SPI_CLK; 
       end 
    end 

    // IMPORTANT:
    // Edge detection is done using r_SPI_CLK and r_PREV_SPI_CLK.
    // SPI_CLK is only the external copy of r_SPI_CLK.
    assign w_Leading_Edge = (r_SPI_CLK == ~w_CPOL) && 
                            (r_PREV_SPI_CLK == w_CPOL); 

    assign w_Trailing_Edge = (r_SPI_CLK == w_CPOL) && 
                             (r_PREV_SPI_CLK == ~w_CPOL); 

    always@(posedge system_clk or negedge rst) 
    begin 
       if(!rst) 
       begin 
          r_SM_State <= idle; 
          SPI_CS <= 1'b1; 
          SPI_MOSI <= 1'b0; 
          tx_ready <= 1'b1; 
          rx_signal <= 1'b0; 
          rx_byte <= 8'h00; 
          r_Bit_Count <= 3'b111;   //  MSB first 
          r_TX_Shift <= 8'h00;
          r_RX_Shift <= 8'h00;
      end  
      else  
      begin 
         rx_signal <= 1'b0; 

         case(r_SM_State) 

           idle : begin 
                     SPI_CS <= 1'b1; 
                     tx_ready <= 1'b1; 

                     if(tx_start)  
                     begin 
                        tx_ready <= 1'b0; 
                        SPI_CS <= 1'b0; 
                        r_TX_Shift <= tx_byte; 
                        r_RX_Shift <= 8'h00;
                        r_Bit_Count <= 3'b111; 
                        r_SM_State <= transfer; 

                        if(!w_CPHA) 
                        begin 
                           SPI_MOSI <= tx_byte[7]; 
                        end 
                     end 
                   end 

            transfer : 
            begin 

               //  CPHA = 0  Logic 
               if(!w_CPHA) 
               begin 
                  //  sample MISO on leading edge 
                  if(w_Leading_Edge) 
                  begin 
                     r_RX_Shift <= {r_RX_Shift[6:0], SPI_MISO}; 
                  end 

                  //  shift MOSI on the trailing edge 
                  if(w_Trailing_Edge) 
                  begin 
                     if(r_Bit_Count == 0) 
                     begin 
                        r_SM_State <= clean_up; 
                     end 
                     else 
                     begin 
                        r_Bit_Count <= r_Bit_Count - 1'b1; 
                        SPI_MOSI <= r_TX_Shift[r_Bit_Count - 1]; 
                     end 
                  end 
               end 

               // CPHA = 1 Logic 
               else begin 
                  // Shift MOSI on Leading Edge 
                  if (w_Leading_Edge) begin 
                      SPI_MOSI <= r_TX_Shift[r_Bit_Count]; 
                  end 

                  // Sample MISO on Trailing Edge 
                  if (w_Trailing_Edge) begin 
                    r_RX_Shift <= {r_RX_Shift[6:0], SPI_MISO}; 
                    if (r_Bit_Count == 0) begin 
                      r_SM_State <= clean_up; 
                    end else begin 
                      r_Bit_Count <= r_Bit_Count - 1'b1; 
                    end 
                  end 
                end 
              end 

          clean_up : 
          begin 
             SPI_CS <= 1'b1; 
             tx_ready <= 1'b1; 
             rx_signal <= 1'b1; 
             rx_byte <= r_RX_Shift; 
             r_SM_State <= idle; 
          end 

          default : r_SM_State <= idle; 
      endcase 
   end 
 end 

endmodule
