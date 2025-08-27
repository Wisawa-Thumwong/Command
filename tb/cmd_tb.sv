`timescale 1 ns / 1 ps
module cmd_tb ();

    //systems
    reg clk;
    reg rst;
    reg rstn;
//===============================================================================================
//Cmd
    //Tx
    reg tx_busy;                     //active when s_axis_tvalid is == 1 and inactive when send stop bit

    reg rx_busy;                     //Active when Rxd is get start bit and inactive shen rxd is get stop bit
    reg rx_overrun_error;
    reg rx_frame_error;

    //I2C Interface
    //Master Command
    wire [6:0] s_cmd_Addr;
    wire s_cmd_start;
    wire s_cmd_read;
    wire s_cmd_write;
    wire s_cmd_write_multiple;
    wire s_cmd_stop;
    wire s_cmd_valid;
    reg s_cmd_ready;
    //AXI4-stream
    wire [7:0] s_cmd_tdata;
    wire s_cmd_tvalid;
    reg s_cmd_tready;
    wire s_cmd_tlast;
    reg [7:0] m_cmd_tdata;
    reg m_cmd_tvalid;
    wire m_cmd_tready;
    reg m_cmd_tlast;

//===========================================================================================
//UART
    reg [7:0]  s_axis_tdata;
    reg s_axis_tvalid;
    wire s_axis_tready;


    //AXI output
    
    wire [7:0]  m_axis_tdata;
    wire m_axis_tvalid;
    reg m_axis_tready;

    
    //UART interface
    
    wire                   rxd;
    wire                   txd;

    reg [7:0] rs_axis_tdata;
    reg rs_axis_tvalid;
    reg rs_axis_tready;

//===========================================================================================
//I2C
    wire scl_i;
    wire scl_o;
    wire scl_t;
    reg sda_i;
    wire sda_o;
    wire sda_t;
    wire busy ;
    wire bus_control;
    wire bus_active ;
    wire missed_ack ;
    reg [15:0] prescale;
    wire stop_on_idle;

//===========================================================================================
//Assignment
    assign rstn = ~rst;

//===========================================================================================  
//PORT MAP
    //UART Interface
    uart #(
        .DATA_WIDTH(8)
    )
    u_uart (
        .clk (clk),
        .rst (rst),

        .s_axis_tdata (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .m_axis_tdata (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .rxd (rxd),
        .txd (txd),
        .tx_busy (tx_busy),
        .rx_busy (rx_busy),
        .rx_overrun_error (rx_overrun_error),
        .rx_frame_error (rx_frame_error),
        .prescale (prescale)
    );

    //For Test bench
    uart_tx #(
        .DATA_WIDTH(8)
    )
    u_uart_tx (
        .clk (clk),
        .rst (rst),

        .s_axis_tdata(rs_axis_tdata),
        .s_axis_tvalid(rs_axis_tvalid),
        .s_axis_tready(rs_axis_tready),
        .txd(rxd),
        .busy(),
        .prescale(prescale)
    );

    //Cmd
    Cmd  u_Cmd(
        .clk (clk),
        .rstn (rstn),

        .tx_busy (tx_busy),
        .s_tdata (s_axis_tdata),
        .s_tvalid (s_axis_tvalid),
        .s_tready (s_axis_tready),
        .m_tdata (m_axis_tdata),
        .m_tvalid (m_axis_tvalid),
        .m_tready (m_axis_tready),
        .rx_busy (rx_busy),
        .rx_overrun_error (),
        .rx_frame_error (),
        .s_cmd_Addr (s_cmd_Addr),
        .s_cmd_start (s_cmd_start),
        .s_cmd_read (s_cmd_read),
        .s_cmd_write (s_cmd_write),
        .s_cmd_write_multiple (s_cmd_write_multiple),
        .s_cmd_stop (s_cmd_stop),
        .s_cmd_valid (s_cmd_valid),
        .s_cmd_ready (s_cmd_ready),
        .s_cmd_tdata (s_cmd_tdata),
        .s_cmd_tvalid (s_cmd_tvalid),
        .s_cmd_tready (s_cmd_tready),
        .s_cmd_tlast (s_cmd_tlast),
        .m_cmd_tdata (m_cmd_tdata),
        .m_cmd_tvalid (m_cmd_tvalid),
        .m_cmd_tready (m_cmd_tready),
        .m_cmd_tlast (m_cmd_tlast),
        .missed_ack(missed_ack)
    );

    //I2C_master
    i2c_master u_i2c_master(
        .clk (clk),
        .rst (rst),

        .s_axis_cmd_address (s_cmd_Addr),
        .s_axis_cmd_start (s_cmd_start),
        .s_axis_cmd_read (s_cmd_read),
        .s_axis_cmd_write (s_cmd_write),
        .s_axis_cmd_write_multiple (s_cmd_write_multiple),
        .s_axis_cmd_stop (s_cmd_stop),
        .s_axis_cmd_valid (s_cmd_valid),
        .s_axis_cmd_ready (s_cmd_ready),
        .s_axis_data_tdata (s_cmd_tdata),
        .s_axis_data_tvalid (s_cmd_tvalid),
        .s_axis_data_tready (s_cmd_tready),
        .s_axis_data_tlast (s_cmd_tlast),
        .m_axis_data_tdata (m_cmd_tdata),
        .m_axis_data_tvalid (m_cmd_tvalid),
        .m_axis_data_tready (m_cmd_tready),
        .m_axis_data_tlast (m_cmd_tlast),
        .scl_i (scl_i),
        .scl_o (scl_o),
        .scl_t (scl_t),
        .sda_i (sda_i),
        .sda_o (sda_o),
        .sda_t (sda_t),
        .busy (busy),
        .bus_control (bus_control),
        .bus_active (bus_active),
        .missed_ack (missed_ack),
        .prescale (prescale),
        .stop_on_idle (stop_on_idle)
    );

//===========================================================================================
//Start process
always begin #10 assign clk = ~clk; end

    initial begin
        clk <= 0;
        rst <= 1;
        rs_axis_tdata <= 0;
        rs_axis_tvalid <= 0;
        prescale <= 0;
        
        sda_i <= 1;
        #200
        rst <= 0;
        prescale <= 20;
        
        sda_i <= 0;

        //Write Mode
        #200
        rs_axis_tdata <= 8'b10011010;       //{Target Addr "1001101" , Write_mode "0"}
        rs_axis_tvalid <= 1;
        #20
        rs_axis_tvalid <= 0;
        #14000
        #18500
        rs_axis_tdata <= 8'b10111011;       //{Conversion "1" , Register Addr "0111011"}
        rs_axis_tvalid <= 1;
        #20
        rs_axis_tvalid <= 0;
        #5500
        #6750


        #300000
        rst <= 1;
        #20
        rst <= 0;

        //Read Mode
        #2000
        rs_axis_tdata <= 8'b10011011;   //{Target Addr "1001101" , Write_mode "1"}
        rs_axis_tvalid <= 1;
        #20
        rs_axis_tvalid <= 0;
        #14000
        #18500
        rs_axis_tdata <= 8'b10111011;       //{Conversion "1" , Register Addr "0111011"}
        rs_axis_tvalid <= 1;
        #20
        rs_axis_tvalid <= 0;
        #200000
        rs_axis_tdata <= 8'b10111011;       //Send Any command for stop
        rs_axis_tvalid <= 1;
        #20
        rs_axis_tvalid <= 0;

        #400000
        $finish;
    end


















endmodule