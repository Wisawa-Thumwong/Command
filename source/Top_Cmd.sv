module Top_Cmp(
    clk,
    rstn,
    Tx,
    Rx,
    scl_pin,
    sda_pin,
    prescale
);

    input wire clk;
    input wire rstn;

    input wire Rx;
    output reg Tx;

    inout wire scl_pin;
    inout wire sda_pin;

    input wire [15:0] prescale;

//===========================================================================================
//Internal Signal
    //systems
    reg rst;            //Active High

    //Uart Tx
    reg [7:0]  s_axis_tdata;
    reg s_axis_tvalid;
    wire s_axis_tready;

    wire [7:0]  m_axis_tdata;
    wire m_axis_tvalid;
    reg m_axis_tready;

    reg [7:0] rs_axis_tdata;
    reg rs_axis_tvalid;
    reg rs_axis_tready;

    reg tx_busy;                     //active when s_axis_tvalid is == 1 and inactive when send stop bit

    reg rx_busy;                     //Active when Rxd is get start bit and inactive shen rxd is get stop bit

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



//===========================================================================================
//Assignment
assign rst = ~rstn;

assign scl_i = scl_pin;
assign scl_pin = scl_t ? 'hz : scl_o;
assign sda_i = sda_pin;
assign sda_pin = sda_t ? 'hz : sda_o;

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
        .prescale (prescale)
    );

    //Command Block
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
        .prescale (prescale),
        .stop_on_idle (stop_on_idle)
    );








endmodule