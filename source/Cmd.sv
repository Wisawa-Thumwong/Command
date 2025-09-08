module Cmd #(
        parameter CRC_En,
        parameter [1:0] MAG_Tempco,
        parameter [2:0] Conv_AVG,
        parameter [1:0] I2C_Rd,
        parameter [2:0] THR_Hyst,
        parameter LP_Ln,
        parameter I2C_Glitch_Filter,
        parameter Trigger_Mode,
        parameter [1:0] Operating_Mode,
        parameter [3:0] MAG_CH_En,
        parameter [3:0] SleepTime,
        parameter T_Rate,
        parameter INTB_Pol,
        parameter MAG_THR_Dir,
        parameter MAG_Gain_CH,
        parameter [1:0] Angle_EN,
        parameter X_Y_Range,
        parameter Z_Range,
        parameter [7:0] Threshold1,
        parameter [7:0] Threshold2,
        parameter [7:0] Threshold3,
        parameter [1:0] WOC_Sel,
        parameter [1:0] Thr_Sel,
        parameter [1:0] Angle_HYS,
        parameter Angle_Offset_En,
        parameter Angle_Offset_Dir,
        parameter Result_INT,
        parameter Threshold_INT,
        parameter INT_State ,
        parameter [2:0] INT_Mode,
        parameter INT_POL_En,
        parameter Mask_INT,
        parameter [7:0] Gain_X_THR_HI,
        parameter [7:0] Offset1_Y_THR_HI,
        parameter [7:0] Offset2_Z_THR_HI,
        parameter [6:0] I2C_Address,
        parameter I2C_Address_Update_En
    )
    (
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
        INT_In,
        INT_Out,
        INT_t,
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

    input wire INT_In;
    output reg INT_Out;
    output reg INT_t;

    input wire missed_ack;

//===============================================================================================
//Internal Signal
//State machine
reg [3:0] state, n_state;
localparam st_idel = 1;                 //Idel State
localparam st_target = 2;               //Get Target State
localparam st_regaddr = 3;              //Get Register State
localparam st_write = 4;                //Sent Write Command State
localparam st_read = 5;                 //Sent Read Command State
localparam st_receive = 6;             //Receives Data From Senser State
localparam st_Int = 7;                  //Interupt State
localparam st_stop = 8;                 //Generate Stop Condition State

//Internal Signal
reg [5:0] cnt_cmd;
reg [9:0] cnt_int;

//Output I2C 
reg rs_cmd_start;
reg rs_cmd_write_multiple = 0;
reg rs_cmd_stop;
reg rs_cmd_valid;

//Output Axi To I2C
reg [7:0] rs_cmd_tdata;
reg rs_cmd_tvalid;
reg rs_cmd_tlast;

//Cmd To I2C
reg rm_cmd_tready;

//Tx to UART
reg [7:0] rs_tdata;
reg rs_tvalid;

//Command From UART
//1st
reg [6:0] Target_Addr;
reg RW_req;
//2nd
reg Conversion;
reg [6:0] reg_addr;

//Real Command Parameter
reg [7:0] command1 = {CRC_En,MAG_Tempco,Conv_AVG,I2C_Rd};
reg [7:0] command2 = {THR_Hyst,LP_Ln,I2C_Glitch_Filter,Trigger_Mode,Operating_Mode};
reg [7:0] command3 = {MAG_CH_En,SleepTime};
reg [7:0] command4 = {T_Rate,INTB_Pol,MAG_THR_Dir,MAG_Gain_CH,Angle_EN,X_Y_Range,Z_Range};
reg [7:0] command5 = {Threshold1};
reg [7:0] command6 = {Threshold2};
reg [7:0] command7 = {Threshold3};
reg [7:0] command8 = {WOC_Sel,Thr_Sel,Angle_HYS,Angle_Offset_En,Angle_Offset_Dir};
reg [7:0] command9 = {Result_INT,Threshold_INT,INT_State,INT_Mode,INT_POL_En,Mask_INT};
reg [7:0] command10 = {Gain_X_THR_HI};
reg [7:0] command11 = {Offset1_Y_THR_HI};
reg [7:0] command12 = {Offset2_Z_THR_HI};
reg [7:0] command13 = {I2C_Address,I2C_Address_Update_En};

//===============================================================================================
//Assignment
assign s_cmd_Addr = Target_Addr;
assign s_cmd_start = rs_cmd_start;
assign s_cmd_write_multiple = rs_cmd_write_multiple;
assign s_cmd_stop = rs_cmd_stop;
assign s_cmd_valid = rs_cmd_valid;

assign s_cmd_tdata = rs_cmd_tdata;
assign s_cmd_tvalid = rs_cmd_tvalid;
assign s_cmd_tlast = rs_cmd_tlast;

assign m_cmd_tready = rm_cmd_tready;

assign s_tdata = rs_tdata;
assign s_tvalid = rs_tvalid;

assign INT_t = INT_Out;

//===============================================================================================
    //State Machine
    always@ (posedge clk) begin 
        if (!rstn) begin
            state <= st_idel;
        end else begin
            state <= n_state;
        end
    end

    //tlast Signal Cmd to I2C
    always@ (posedge clk) begin 
        if (!rstn) begin
            rs_cmd_tlast <= 0;
        end else begin
            if (state == st_write) begin
                if (s_cmd_tready == 1 && cnt_cmd == 13) begin
                    rs_cmd_tlast <= 1;
                end else begin
                    rs_cmd_tlast <= 0;
                end
            end else if (state == st_read) begin
                if (s_cmd_tready == 1 && cnt_cmd == 0) begin
                    rs_cmd_tlast <= 1;
                end else begin
                    rs_cmd_tlast <= 0;
                end
            end else begin
                rs_cmd_tlast <= 0;
            end
        end
    end
    
    //Next State Machine
    always@ (posedge clk) begin
        if (!rstn) begin
            n_state <= st_idel;
        end else begin
            case (state) 
                //Rx Start Send Data to Command Block
                st_idel :   if (rx_busy == 1) begin
                                n_state <= st_target;
                            end else if (n_state == st_target) begin
                                            n_state <= n_state;
                            end else begin
                                n_state <= st_idel;
                            end

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
                
                //Sent Write Command to Senser
                st_write :  if (cnt_cmd == 14 && s_cmd_ready == 1 && s_cmd_write == 0) begin
                                n_state <= st_stop;
                            end else begin
                                n_state <= n_state; 
                            end
                
                //Sent Read Command to Sensor
                st_read : 
                            if (cnt_cmd == 1 && s_cmd_stop == 1 && s_cmd_valid == 1 && s_cmd_ready == 1) begin
                                n_state <= st_receive;
                            end else if(n_state == st_receive) begin
                                n_state <= st_receive;
                            end else begin
                                n_state <= st_read;
                            end

                //Receive data from senser
                st_receive : 
                            if (rx_busy == 1) begin
                                n_state <= st_stop;
                            end else begin
                                if (cnt_int == 13) begin
                                    n_state <= st_Int;
                                end else begin
                                    n_state <= st_receive;
                                end
                            end

                //Interupt State
                st_Int :
                            if (rx_busy == 1) begin              
                                //n_state <= st_stop;
                            end else begin
                                if (s_cmd_ready == 1) begin
                                    n_state <= st_read;
                                end else begin
                                    n_state <= n_state;
                                end
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
            RW_req <= 0;
        end else begin
            if (state == st_target) begin
                Target_Addr <= m_tdata[7:1];
                RW_req <= m_tdata[0];
            end else begin
                Target_Addr <= Target_Addr;
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
            if (state == st_write || state == st_read || state == st_stop || state == st_receive) begin
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
            if (state == st_write) begin
                if (s_cmd_ready == 1 && cnt_cmd == 0) begin
                    rs_cmd_start <= 1;
                end else begin
                    rs_cmd_start <= 0;
                end
            end else if (state == st_read) begin                            //create start signal when already get Register Addr
                if (s_cmd_ready == 1 && cnt_cmd == 0) begin
                    rs_cmd_start <= 1;
                end else begin
                    rs_cmd_start <= 0;
                end
            end else if(state == st_receive) begin                         //create start signal when send 1st Target Addr and Re-Start Signal
                if (s_cmd_ready == 1 && cnt_cmd != 2) begin
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
            if (state == st_write) begin
                if (s_cmd_ready == 1 && cnt_cmd == 14) begin
                    rs_cmd_stop <= 1;
                end else begin
                    rs_cmd_stop <= 0;
                end
            end else if (state == st_read) begin
                if (s_cmd_ready == 1 && cnt_cmd == 1) begin
                    rs_cmd_stop <= 1;
                end else begin
                    rs_cmd_stop <= 0;
                end
            end else if (state == st_read && cnt_cmd == 1) begin
                if (s_cmd_tready == 1 && rs_cmd_tvalid == 1) begin
                    rs_cmd_stop <= 1;
                end else begin
                    rs_cmd_stop <= 0;
                end
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
            if (s_cmd_ready == 1) begin
                if (state == st_write || state == st_read || state == st_receive) begin
                    rs_cmd_valid <= 1;
                end else begin
                    rs_cmd_valid <= 0;
                end 
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
                if (cnt_cmd == 15) begin
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
            end else if (state == st_receive) begin
                if (cnt_cmd == 2) begin
                    cnt_cmd <= cnt_cmd;
                end else if (s_cmd_start == 1) begin
                    cnt_cmd <= cnt_cmd + 1;
                end else begin
                    cnt_cmd <= cnt_cmd;
                end
            end else begin
                cnt_cmd <= 0;
            end
        end
    end

    //Create write Signal to I2C block for Write read command to senser
    always@ (posedge clk) begin
        if (!rstn) begin
            s_cmd_write <= 0;
        end else begin
            if (state == st_write) begin
                if (cnt_cmd != 14) begin
                    s_cmd_write <= 1;
                end else begin
                    s_cmd_write <= 0;
                end
            end else if (state == st_read) begin
                if (cnt_cmd == 1) begin
                    s_cmd_write <= 0;
                end else begin
                    s_cmd_write <= 1;
                end 
            end else if (state == st_Int) begin
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
            if (state == st_receive) begin
                if (s_cmd_ready == 1 && s_cmd_valid == 1) begin
                    if (cnt_int >= 12) begin
                        s_cmd_read <= 0;
                    end else begin
                        s_cmd_read <= 1;
                    end
                end
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
            end else if (state == st_read) begin
                //Command For Read Mode
                case (cnt_cmd)
                    0 : rs_cmd_tdata <= {Conversion,reg_addr};
                    1 : rs_cmd_tdata <= 1'hx;
                    2 : rs_cmd_tdata <= 1'hx;
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
                        rs_cmd_tvalid <= rs_cmd_tvalid;
                    end else begin
                        rs_cmd_tvalid <= 1;
                    end
                end else begin
                    rs_cmd_tvalid <= 0;
                end
            end else if (state == st_read) begin
                if (s_cmd_tready == 1) begin
                    if (cnt_cmd == 1) begin                 //Last Read Command
                        rs_cmd_tvalid <= 0;
                    end else begin
                        rs_cmd_tvalid <= 1;
                    end
                end else begin
                    rs_cmd_tvalid <= 0;
                end
            end else if (state == st_receive) begin
                if (s_cmd_tready == 1) begin
                    if (cnt_cmd == 1) begin
                        rs_cmd_tvalid <= 1;
                    end else begin
                        rs_cmd_tvalid <= 0;
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
            if (state == st_receive || state == st_Int) begin         //Tx not busy && in Read mode
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
            if (state == st_receive) begin
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
            if (state == st_receive) begin
                if (rm_cmd_tready == 1 && m_cmd_tvalid == 1) begin
                    rs_tvalid <= m_cmd_tvalid;
                end else begin
                    rs_tvalid <= 0;
                end
            end else begin
                rs_tvalid <= 0;
            end
        end
    end

    //Data Received Counter
    always@ (posedge clk) begin
        if (!rstn) begin
            cnt_int <= 0;
        end else begin
            if (state == st_receive) begin
                if (rm_cmd_tready == 1 && m_cmd_tvalid == 1) begin
                    if (cnt_int == 13) begin
                        cnt_int <= 0;
                    end else begin    
                        cnt_int <= cnt_int + 1;
                    end
                end else begin
                    cnt_int <= cnt_int;
                end
            end else if (state == st_Int) begin
                if (cnt_int == 13) begin
                    cnt_int <= 0;
                end else if (s_cmd_ready == 1 && s_cmd_valid == 1) begin
                    cnt_int <= cnt_int + 1;
                end else begin
                    cnt_int <= cnt_int;
                end
            end else if (state == st_idel) begin
                cnt_int <= 0;
            end else begin
                cnt_int <= cnt_int;
            end
        end
    end

    //Interupt Output
    /*always@ (posedge clk) begin
        if (!rstn) begin
            INT_Out <= 1;
        end else begin
            if (state == st_read || state == st_Int) begin                  //Active Low
                INT_Out <= 0;
            end else begin
                INT_Out <= 1;
            end
        end
    end*/

//===============================================================================================
endmodule