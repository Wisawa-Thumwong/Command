module Top_Cmp(
    clk,
    rstn,
    Tx,
    Rx,
    scl_pin,
    sda_pin,
    INT_Pin,

);

    input wire clk;
    input wire rstn;

    input wire Rx;
    output reg Tx;

    inout wire scl_pin;
    inout wire sda_pin;

    inout wire INT_Pin;

//===========================================================================================
//Internal Signal
    //systems
    reg rst;                           //Active High
    reg [15:0] prescale_Uart = 54;       //921600 = 7, | 14 = 460800 | 54 = 115200
    reg [15:0] prescale_I2C = 32;      //Max 1MHz = 13 | Standard 400KHz = 32 | 100KHz = 132

    //UART Tx
    reg [7:0]  s_axis_tdata;
    reg s_axis_tvalid;
    wire s_axis_tready;
    reg tx_busy;                       //Active when s_axis_tvalid is == 1 and inactive when send stop bit

    //UART Rx
    wire [7:0]  m_axis_tdata;
    wire m_axis_tvalid;
    reg m_axis_tready;
    reg rx_busy;                       //Active when Rxd is get start bit and inactive shen rxd is get stop bit

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

    wire scl_i;
    wire scl_o;
    wire scl_t;
    reg sda_i;
    wire sda_o;
    wire sda_t;
    //AXI4-stream to Slave
    wire [7:0] s_cmd_tdata;
    wire s_cmd_tvalid;
    reg s_cmd_tready;
    wire s_cmd_tlast;
    //AXI4-stream to Master
    reg [7:0] m_cmd_tdata;
    reg m_cmd_tvalid;
    wire m_cmd_tready;
    reg m_cmd_tlast;

    wire missed_ack;
    wire busy;
    wire bus_active;
    wire bus_control;
    wire stop_on_idle;

    reg INT_In;
    wire INT_Out;
    wire INT_t;
//===========================================================================================
//Assignment
assign rst = !rstn;

assign scl_i = scl_pin;
assign scl_pin = scl_t ? 'hz : scl_o;
assign sda_i = sda_pin;
assign sda_pin = sda_t ? 'hz : sda_o;

assign INT_In = INT_Pin;
assign INT_Pin = INT_t ? 'hz : INT_Out;

//===========================================================================================
//Component
    //UART
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
        .rxd (Rx),
        .txd (Tx),
        .tx_busy (tx_busy),
        .rx_busy (rx_busy),
        .rx_overrun_error (),
        .rx_frame_error (),
        .prescale (prescale_Uart)
    );

    //Command Block
    Cmd  #(
        .CRC_En(1'h0), 
        .MAG_Tempco(2'h0),
        .Conv_AVG(3'h0),
        .I2C_Rd(2'h0),
        .THR_Hyst(3'h0),
        .LP_Ln(1'h1),
        .I2C_Glitch_Filter(1'h0),
        .Trigger_Mode(1'h1),   
        .Operating_Mode(2'h2),
        .MAG_CH_En(4'h7),
        .SleepTime(4'h0),
        .T_Rate(1'h0),
        .INTB_Pol(1'h0),
        .MAG_THR_Dir(1'h0),
        .MAG_Gain_CH(1'h0),
        .Angle_EN(2'h0),
        .X_Y_Range(1'h0),
        .Z_Range(1'h0),
        .Threshold1(8'h0),
        .Threshold2(8'h0),
        .Threshold3(8'h0),
        .WOC_Sel(2'h0),
        .Thr_Sel(2'h0),
        .Angle_HYS(2'h0),
        .Angle_Offset_En(1'h0),
        .Angle_Offset_Dir(1'h0),
        .Result_INT(1'h1),
        .Threshold_INT(1'h0),
        .INT_State(1'h0),
        .INT_Mode(3'h1),  
        .INT_POL_En(1'h1),
        .Mask_INT(1'h0), 
        .Gain_X_THR_HI(8'h0),
        .Offset1_Y_THR_HI(8'h0),
        .Offset2_Z_THR_HI(8'h0),
        .I2C_Address(7'h34),
        .I2C_Address_Update_En(1'h0)
    )
    u_Cmd(
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
        .INT_In (INT_In),
        .INT_Out (INT_Out),
        .INT_t (INT_t),
        .missed_ack(missed_ack)
    );

    //I2C Master Block
    i2c_master u_i2c_master(
        .clk (clk),
        .rst (rst),

        .s_axis_cmd_address (s_cmd_Addr),
        .s_axis_cmd_start (s_cmd_start),
        .s_axis_cmd_read (s_cmd_read),
        .s_axis_cmd_write (s_cmd_write_multiple),
        .s_axis_cmd_write_multiple (s_cmd_write),
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
        .prescale (prescale_I2C),
        .stop_on_idle (stop_on_idle)
    );

endmodule