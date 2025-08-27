module Cmd (
    clk,
    rstn,
    tx_busy,
    s_tdata,
    s_tvalid,
    s_tready,
    m_tdata,
    m_tvalid,
    m_tready,
    rx_busy,
    rx_overrun_error,
    rx_frame_error,
    s_cmd_Addr,
    s_cmd_start,
    s_cmd_read,
    s_cmd_write,
    s_cmd_write_multiple,
    s_cmd_stop,
    s_cmd_valid,
    s_cmd_ready,
    s_cmd_tdata,
    s_cmd_tvalid,
    s_cmd_tready,
    s_cmd_tlast,
    m_cmd_tdata,
    m_cmd_tvalid,
    m_cmd_tready,
    m_cmd_tlast,
    missed_ack
);

    //systems
    input wire clk;
    input wire rstn;
    //===============================================================================================
    //Uart Interface
    //Tx
    input wire tx_busy;                     //active when s_axis_tvalid is == 1 and inactive when send stop bit
    output reg[7:0] s_tdata;
    output reg s_tvalid;
    input wire s_tready;
    //Rx
    input wire[7:0] m_tdata;
    input wire m_tvalid;
    output reg m_tready;
    input wire rx_busy;                     //Active when Rxd is get start bit and inactive shen rxd is get stop bit
    input wire rx_overrun_error;
    input wire rx_frame_error;
    //===============================================================================================
    //I2C Interface
    //Master Command
    output reg [6:0] s_cmd_Addr;
    output reg s_cmd_start;
    output reg s_cmd_read;
    output reg s_cmd_write;
    output reg s_cmd_write_multiple;
    output reg s_cmd_stop;
    output reg s_cmd_valid;
    input wire s_cmd_ready;
    //AXI4-stream
    output reg [7:0] s_cmd_tdata;
    output reg s_cmd_tvalid;
    input wire s_cmd_tready;
    output reg s_cmd_tlast;

    input wire [7:0] m_cmd_tdata;
    input wire m_cmd_tvalid;
    output reg m_cmd_tready;
    input wire m_cmd_tlast;

    input wire missed_ack;



//===============================================================================================
//Internal Signal

//State machine
reg [3:0] state, n_state;
localparam st_idel = 0;
localparam st_target = 1;
localparam st_regaddr = 2;
localparam st_write = 3;
localparam st_read = 4;
localparam st_read_con = 5;
localparam st_stop = 6;

//Internal Signal
reg [5:0] cnt_cmd;

//Output I2C 
reg rs_cmd_start;
reg rs_cmd_write_multiple = 0;
reg rs_cmd_stop;
reg rs_cmd_valid;
reg RW_mode;
//Output Axi To I2C
reg [7:0] rs_cmd_tdata;
reg rs_cmd_tvalid;
//reg rs_cmd_tlast;

//Mt_Sl
reg rm_cmd_tready;

//Tx to UART
reg rs_tdata;
reg rs_tvalid;

//Command From UART
//1st
reg [6:0] Target_Addr;
reg RW_req;
//2nd
reg Conversion;
reg [6:0] reg_addr;

//Real Command Parameter
/*reg [7:0] command1 = 8'b00000001;
reg [7:0] command2 = 8'b00010110;
reg [7:0] command3 = 8'b00010000;
reg [7:0] command4 = 8'b11000000;
reg [7:0] command5 = 8'b00000000;
reg [7:0] command6 = 8'b00000000;
reg [7:0] command7 = 8'b00000000;
reg [7:0] command8 = 8'b00000000;
reg [7:0] command9 = 8'b11000100;
reg [7:0] command10 = 8'b00000000;
reg [7:0] command11 = 8'b00000000;
reg [7:0] command12 = 8'b00000000;
reg [7:0] command13 = 8'b00011101;*/

//Test Data Command Parameter
reg [7:0] command1 = 8'd01;
reg [7:0] command2 = 8'd02;
reg [7:0] command3 = 8'd03;
reg [7:0] command4 = 8'd04;
reg [7:0] command5 = 8'd05;
reg [7:0] command6 = 8'd06;
reg [7:0] command7 = 8'd07;
reg [7:0] command8 = 8'd08;
reg [7:0] command9 = 8'd09;
reg [7:0] command10 = 8'd10;
reg [7:0] command11 = 8'd11;
reg [7:0] command12 = 8'd12;
reg [7:0] command13 = 8'd13;


//===============================================================================================
//Assignment
assign s_cmd_Addr = Target_Addr;
assign s_cmd_start = rs_cmd_start;
assign s_cmd_write_multiple = rs_cmd_write_multiple;
assign s_cmd_stop = rs_cmd_stop;
assign s_cmd_valid = rs_cmd_valid;

assign s_cmd_tdata = rs_cmd_tdata;
assign s_cmd_tvalid = rs_cmd_tvalid;
assign s_cmd_tlast = rs_cmd_stop;

assign m_cmd_tready = rm_cmd_tready;

assign s_tdata = rs_tdata;
assign s_tvalid = rs_tvalid;


//===============================================================================================
    //State Machine
    always@ (posedge clk) begin 
        if (!rstn) begin
            state <= st_idel;
        end else begin
            state <= n_state;
        end 
    end

    //Next State
    always@ (posedge clk) begin
        if (!rstn) begin
            n_state <= st_idel;
        end else begin
            case (state) 
                //Rx Start Send Data to Command Block
                st_idel : n_state = (rx_busy == 1) ? st_target : st_idel;

                //Get Target Address and Read/Write Mode
                st_target : if (m_tvalid == 1 && m_tready == 1) begin
                                n_state <= st_regaddr;
                            end else begin
                                if (n_state == st_regaddr) begin
                                    n_state <= st_regaddr;
                                end else begin
                                    n_state <= st_target;
                                end
                            end
                
                //Get Conversion bit and Register Address
                st_regaddr : 
                            if (m_tvalid == 1 && m_tready == 1) begin
                                if (RW_req == 1) begin
                                    n_state <= st_read;
                                end else begin
                                    n_state <= st_write;
                                end
                            end else if (n_state == st_write) begin
                                n_state <= st_write;
                            end else if (n_state == st_read) begin
                                n_state <= st_read;
                            end else begin
                                n_state <= st_regaddr;
                            end
                
                //Write Command to Senser
                st_write :  if (cnt_cmd == 13 && s_cmd_tready == 1 && s_cmd_tvalid == 1) begin
                                n_state <= st_stop;
                            end else begin
                                n_state <= n_state; 
                            end
                
                //Read State send Senser Start Command 
                st_read : 
                            if (cnt_cmd == 1 && s_cmd_tready == 1 && s_cmd_tvalid == 1) begin
                                n_state <= st_read_con;
                            end else if(n_state == st_read_con) begin
                                n_state <= n_state;
                            end else begin
                                n_state <= st_read;
                            end

                //Receive Infomation data from senser
                st_read_con : 
                            if (m_tvalid == 1) begin
                                n_state <= st_stop;
                            end else begin
                               n_state <= st_read_con;
                            end

                //Create Stop signal condition
                st_stop : n_state <= st_idel;

            endcase
        end
    end

//===============================================================================================
//Command From UART
    //1st Input Command from UART
    always@ (posedge clk) begin
        if (!rstn) begin
            Target_Addr <= 0;
            RW_mode <= 0;
            RW_req <= 0;
        end else begin
            if (state == st_target && m_tvalid == 1) begin
                Target_Addr <= m_tdata[7:1];
                RW_mode <= m_tdata[0];
                RW_req <= m_tdata[0];
            end else begin
                Target_Addr <= Target_Addr;
                RW_mode <= RW_mode;
                RW_req <= RW_req;
            end
        end
    end

    //2nd Input Command from UART
    always@ (posedge clk) begin
        if (!rstn) begin
            Conversion <= 0;
            reg_addr <= 0;
        end else begin
            if (state == st_regaddr && m_tvalid == 1) begin
                Conversion <= m_tdata[7];
                reg_addr <= m_tdata[6:0];
            end else begin
                Conversion <= Conversion;
                reg_addr <= reg_addr;
            end
        end
    end

    //m_tready : Ready signal from Cmd to UART for RX Path
    always@ (posedge clk) begin
        if (!rstn) begin
            m_tready <= 0;
        end else begin
            if (state == st_write || state == st_read || state == st_stop || state == st_read_con) begin
                m_tready <= 0;
            end else begin
                m_tready <= 1;
            end
        end
    end

//===============================================================================================
//Write Process Master I2C
    //rs_cmd_start : create Start command from Cmd to I2C IP
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_cmd_start <= 0;
        end else begin
            if (state == st_regaddr) begin                          //create start signal when already get Register Addr
                if (m_tready == 1 && m_tvalid == 1) begin
                    rs_cmd_start <= 1;
                end else begin
                    rs_cmd_start <= 0;
                end
            end else if(state == st_read && cnt_cmd == 1) begin     //create start signal when send 1st Target Addr and Re-Start Signal
                if (s_cmd_tready == 1 && rs_cmd_tvalid == 1) begin
                    rs_cmd_start <= 1;
                end else begin
                    rs_cmd_start <= 0;
                end
            end else begin
                rs_cmd_start <= 0;
            end
        end
    end

    //rs_cmd_stop : create Stop command from Cmd to I2C IP
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_cmd_stop  <= 0;
        end else begin
            if (state == st_stop) begin
                rs_cmd_stop <= 1;
            end else begin
                rs_cmd_stop <= 0;
            end
        end
    end

    //rs_cmd_valid : create Valid Command signal from Cmd to I2C IP
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_cmd_valid <= 0;
        end else begin
            if (state == st_write) begin
                rs_cmd_valid <= 1;
            end else if(state == st_read) begin
                rs_cmd_valid <= 1;
            end else begin
                rs_cmd_valid <= 0;
            end
        end
    end

    //cnt_cmd : Counter of Command (2+13) to I2C
    always@ (posedge clk) begin
        if (!rstn) begin
            cnt_cmd <= 0;
        end else begin
            if (state == st_write) begin
                if (cnt_cmd == 14) begin
                    cnt_cmd <= 0;
                end else if (s_cmd_tready == 1 && rs_cmd_tvalid == 1) begin
                    cnt_cmd <= cnt_cmd + 1;
                end else begin
                    cnt_cmd <= cnt_cmd;
                end
            end else if (state == st_read) begin
                if (cnt_cmd == 3) begin
                    cnt_cmd <= 0;
                end else if (s_cmd_tready == 1 && rs_cmd_tvalid == 1) begin
                    cnt_cmd <= cnt_cmd + 1;
                end else begin
                    cnt_cmd <= cnt_cmd;
                end
            end
        end
    end

    //Create write Signal to I2C block for Write read command to senser
    always@ (posedge clk) begin
        if (!rstn) begin
            s_cmd_write <= 0;
        end else begin
            if (state == st_read || state == st_write) begin
                s_cmd_write <= 1;
            end else begin
                s_cmd_write <= 0;
            end
        end
    end

    //Create read signal to I2C Block for Read Mode
    always@ (posedge clk) begin
        if (!rstn) begin
            s_cmd_read <= 0;
        end else begin
            if (state == st_read_con) begin
                s_cmd_read <= 1;
            end else begin
                s_cmd_read <= 0;
            end
        end
    end

    //rs_cmd_tdata : Process Command Data to I2C
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_cmd_tdata <= 0;
        end else begin
            if (state == st_write) begin
                //Command for Write Mode
                case (cnt_cmd) 
                    0 : rs_cmd_tdata <= {Conversion,reg_addr};
                    1 : rs_cmd_tdata <= command1;
                    2 : rs_cmd_tdata <= command2;
                    3 : rs_cmd_tdata <= command3;
                    4 : rs_cmd_tdata <= command4;
                    5 : rs_cmd_tdata <= command5;
                    6 : rs_cmd_tdata <= command6;
                    7 : rs_cmd_tdata <= command7;
                    8 : rs_cmd_tdata <= command8;
                    9 : rs_cmd_tdata <= command9;
                    10 : rs_cmd_tdata <= command10;
                    11 : rs_cmd_tdata <= command11;
                    12 : rs_cmd_tdata <= command12;
                    13 : rs_cmd_tdata <= command13;
                endcase
            end else if (state == st_read || state == st_read_con) begin
                //Command For Read Mode
                case (cnt_cmd)
                    0 : rs_cmd_tdata <= {Conversion,reg_addr};
                    1 : rs_cmd_tdata <= {Target_Addr,1'b1};
                endcase
            end
        end
    end

    //rs_cmd_tvalid : s_cmd_tvalid : Valid signal from Cmd to I2C For Send Command Data 
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_cmd_tvalid <= 0;
        end else begin
            if (state == st_write) begin
                if (s_cmd_tready == 1) begin
                    if (cnt_cmd == 14) begin                //Last Write Command
                        rs_cmd_tvalid <= 0;
                    end else begin
                        rs_cmd_tvalid <= 1;
                    end
                end else begin
                    rs_cmd_tvalid <= 0;
                end
            end else if (state == st_read || state == st_read_con) begin
                if (s_cmd_tready == 1) begin
                    if (cnt_cmd == 3) begin                 //Last Read Command
                        rs_cmd_tvalid <= 0;
                    end else begin
                        rs_cmd_tvalid <= 1;
                    end
                end else begin
                    rs_cmd_tvalid <= 0;
                end
            end else begin
                rs_cmd_tvalid <= 0;
            end
        end
    end

//===============================================================================================

    //Bypass Ready signal from Tx UART to m_tready of I2C
    always@ (posedge clk) begin
        if (!rstn) begin
            rm_cmd_tready <= 0;
        end else begin
            if (!tx_busy && state == st_read_con) begin         //Tx not busy && in Read mode
                rm_cmd_tready <= s_tready;
            end else begin
                rm_cmd_tready <= 0;
            end 
        end
    end

    //Bypass Data Signal from I2C Master to Tx UART when in Read Information mode
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_tdata <= 0;
        end else begin
            if (state == st_read_con) begin
                if (rm_cmd_tready == 1 && m_cmd_tvalid == 1) begin
                    rs_tdata <= m_cmd_tdata;
                end else begin
                    rs_tdata <= 0;
                end
            end
        end
    end

    //Bypass Valid Signal from I2C Master to Tx UART when in Read Information mode
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_tvalid <= 0;
        end else begin
            if (state == st_read_con) begin
                if (rm_cmd_tready == 1 && m_cmd_tvalid == 1) begin
                    rs_tvalid <= m_cmd_tvalid;
                end else begin
                    rs_tvalid <= 0;
                end
            end
        end
    end

//===============================================================================================
endmodule