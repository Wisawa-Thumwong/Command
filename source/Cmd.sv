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



//State machine
reg [3:0] state, n_state;
localparam st_idel = 0;
localparam st_target = 1;
localparam st_regaddr = 2;
localparam st_write = 3;
localparam st_read = 4;
localparam st_stop = 5;

//Internal Signal
reg [5:0] cnt_cmd;
reg [2:0] cnt_read;

//Output I2C 
reg rs_cmd_start;
reg rs_cmd_read;
reg rs_cmd_write;
reg rs_cmd_write_multiple = 0;
reg rs_cmd_stop;
reg rs_cmd_valid;
reg RW_mode;
//Output Axi To I2C
reg [7:0] rs_cmd_tdata;
reg rs_cmd_tvalid;
reg rs_cmd_tlast;

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
reg [7:0] command13 = 8'b00011101; */             //set Target Addr = 7'b0001110

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



//Assignment
assign s_cmd_Addr = Target_Addr;
assign s_cmd_start = rs_cmd_start;
assign s_cmd_read = RW_mode == 1 ? 1 : 0;
assign s_cmd_write = RW_mode == 0 ? 1 : 0;
assign s_cmd_write_multiple = rs_cmd_write_multiple;
assign s_cmd_stop = rs_cmd_stop;
assign s_cmd_valid = rs_cmd_valid;

assign s_cmd_tdata = rs_cmd_tdata;
assign s_cmd_tvalid = rs_cmd_tvalid;
assign s_cmd_tlast = rs_cmd_tlast;

assign m_cmd_tready = rm_cmd_tready;

assign s_tdata = rs_tdata;
assign s_tvalid = rs_tvalid;


//===============================================================================================
//RX UART
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
                st_idel : n_state = (rx_busy == 1) ? st_target : st_idel;
                st_target : if (m_tvalid == 1 && m_tready == 1) begin
                                n_state <= st_regaddr;
                            end else begin
                                if (n_state == st_regaddr) begin
                                    n_state <= st_regaddr;
                                end else begin
                                    n_state <= st_target;
                                end
                            end
                //n_state = (m_tvalid == 1 && m_tready == 1) ? st_regaddr : (n_state == st_regaddr) : st_regaddr : st_target;

                st_regaddr : if (m_tvalid == 1 && m_tready == 1) begin
                                if (RW_mode == 1) begin
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
                //n_state = (m_tvalid == 0 && Din == Din) ? st_regaddr : (RW_mode == 0) ? st_write : st_read;
                
                st_write :  if (cnt_cmd == 15) begin
                                n_state <= st_stop;
                            end else begin
                                n_state <= n_state; 
                            end
                //n_state = (cnt_cmd == 13) ? st_stop : st_write;

                st_read : if (m_tvalid == 1) begin
                                n_state <= st_stop;
                            end else begin
                                n_state <= n_state; 
                            end
                //n_state = (m_tvalid == 1) ? st_stop : st_read;

                st_stop : n_state <= st_idel;
            endcase
        end
    end

//Command From UART
    //1st Command
    always@ (posedge clk) begin
        if (!rstn) begin
            Target_Addr <= 0;
            RW_mode <= 0;
        end else begin
            if (state == st_target && m_tvalid == 1) begin
                Target_Addr <= m_tdata[7:1];
                RW_mode <= m_tdata[0];
            end else begin
                Target_Addr <= Target_Addr;
                RW_mode <= RW_mode;
            end
        end
    end

    //2nd Command
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
            if (state == st_write && state == st_read && state == st_stop) begin
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
            if (state == st_regaddr) begin
                if (m_tready == 1 && m_tvalid == 1) begin
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
                if (cnt_cmd == 15) begin
                    cnt_cmd <= 0;
                end else if (s_cmd_tready == 1 && rs_cmd_tvalid == 1) begin
                    cnt_cmd <= cnt_cmd + 1;
                end else begin
                    cnt_cmd <= cnt_cmd;
                end
            end else begin
                cnt_cmd <= 0;
            end
        end
    end

    //rs_cmd_tlast : Last Command
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_cmd_tlast <= 0;
        end else begin
            if (state == st_write) begin
                if (cnt_cmd == 13 && (s_cmd_tready == 1 && rs_cmd_tvalid == 1)) begin
                    rs_cmd_tlast <= 1;
                end else begin
                    rs_cmd_tlast <= 0;
                end
            end
        end
    end


    //rs_cmd_tdata : Process Command Data to I2C
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_cmd_tdata <= 0;
        end else begin
            case (cnt_cmd) 
                0 : rs_cmd_tdata <= {Target_Addr,RW_mode};
                1 : rs_cmd_tdata <= {Conversion,reg_addr};
                2 : rs_cmd_tdata <= command1;
                3 : rs_cmd_tdata <= command2;
                4 : rs_cmd_tdata <= command3;
                5 : rs_cmd_tdata <= command4;
                6 : rs_cmd_tdata <= command5;
                7 : rs_cmd_tdata <= command6;
                8 : rs_cmd_tdata <= command7;
                9 : rs_cmd_tdata <= command8;
                10 : rs_cmd_tdata <= command9;
                11 : rs_cmd_tdata <= command10;
                12 : rs_cmd_tdata <= command11;
                13 : rs_cmd_tdata <= command12;
                14 : rs_cmd_tdata <= command13;
            endcase
        end
    end

    //
    //rs_cmd_tvalid : s_cmd_tvalid : Valid signal from Cmd to I2C For Send Command Data 
    always@ (posedge clk) begin
        if (!rstn) begin
            rs_cmd_tvalid <= 0;
        end else begin
            if (state == st_write) begin
                if (s_cmd_tready == 1) begin
                    if (cnt_cmd == 15 && state == st_stop) begin
                        rs_cmd_tvalid <= 0;
                    end else begin
                        rs_cmd_tvalid <= 1;
                    end
                end else begin
                    rs_cmd_tvalid <= 0;
                end
            end
        end
    end

//===============================================================================================
//Slave I2C

/*always@ (posedge clk) begin
    if (!rstn) begin
        rm_cmd_tready <= 0;
    end else begin
        if (!tx_busy && state == st_read) begin
            rm_cmd_tready <= 1;
        end else begin
            rm_cmd_tready <= 0;
        end 
    end
end*/

//===============================================================================================
//Tx to UART

/*always@ (posedge clk) begin
    if (!rstn) begin
        rs_tdata <= 0;
    end else begin
        if (state == st_read) begin
            if (rm_cmd_tready == 1 && m_cmd_tvalid == 1) begin
                rs_tdata <= m_cmd_tdata;
            end else begin
                rs_tdata <= 0;
            end
        end
    end
end

always@ (posedge clk) begin
    if (!rstn) begin
        rs_tvalid <= 0;
    end else begin
        if (state == st_read) begin
            if (rm_cmd_tready == 1 && m_cmd_tvalid == 1) begin
                rs_tvalid <= 1;
            end else begin
                rs_tvalid <= 0;
            end
        end
    end
end*/

//===============================================================================================
//Read Mode
    //cnt_read
    /*always@ (posedge clk) begin
        if (!rstn) begin
            cnt_read <= 0;
        end else begin
            if (state == st_read) begin
                if (cnt_read == 3) begin
                    cnt_read <= 0;
                end else if (s_cmd_tready == 1 && rs_cmd_tvalid == 1) begin
                    cnt_read <= cnt_read + 1;
                end else begin
                    cnt_read <= cnt_read;
                end
            end
        end
    end*/



//===============================================================================================


endmodule