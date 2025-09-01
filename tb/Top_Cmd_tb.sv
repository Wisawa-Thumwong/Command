`timescale 1 ns / 1 ps

module Top_Cmd_tb ();

    reg clk;
    reg rstn;

    reg Rx;
    wire Tx;

    reg [15:0] prescale;

    wand scl_pin;
    wand sda_pin;

    wire INT_Pin;

    reg [7:0] rs_axis_tdata;
    reg rs_axis_tvalid;
    reg rs_axis_tready;

//===========================================================================================
//Component
    Top_Cmp u_Top_Cmp (
        .clk(clk),
        .rstn(rstn),
        .Tx(Tx),
        .Rx(Rx),
        .scl_pin(scl_pin),
        .sda_pin(sda_pin),
        .INT_Pin(INT_Pin)
    );

    //For Test Bench
    uart_tx #(
        .DATA_WIDTH(8)
    )
    u_uart_tx (
        .clk (clk),
        .rst (rst),

        .s_axis_tdata(rs_axis_tdata),
        .s_axis_tvalid(rs_axis_tvalid),
        .s_axis_tready(rs_axis_tready),
        .txd(Rx),
        .busy(),
        .prescale(prescale)
    );

//===========================================================================================
//Generate Clock
always begin #10 assign clk = ~clk; end

//===========================================================================================
//Assignment
assign sda_pin = 1'b1;
assign scl_pin = 1'b1;
assign rst = ~rstn;
//===========================================================================================
//Start process

    initial begin
        clk <= 0;
        rstn <= 0;
        prescale <= 0;
        rs_axis_tdata <= 0;
        rs_axis_tvalid <= 0;
        //rs_axis_tready <= 0;
        #200 /////////////////
        rstn <= 1;
        prescale <= 54;
        //rs_axis_tready <= 1;
        #200
        rs_axis_tdata <= 8'b01101001;        //Read Addr "0110100"
        rs_axis_tvalid <= 1;
        #20
        rs_axis_tvalid <= 0;
        #200000
        //#8000000
        rs_axis_tdata <= 8'b10010100;       //{Conversion "1" , Register Addr "0010100"}
        rs_axis_tvalid <= 1;
        #20
        rs_axis_tvalid <= 0;
        #5500
        #6750
        /*
        #300000
        rstn <= 0;
        #20
        rstn <= 1;

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
        rs_axis_tvalid <= 0;*/
        #2000000
        $finish;

    end





endmodule