`timescale 1ns / 1ps

module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11,
    parameter IDLE = 5'd0,
    parameter START = 5'd1,
    parameter INIT_0 = 5'd2,
    parameter INIT_1 = 5'd3,
    parameter INIT_2 = 5'd4,
    parameter COEF_10 = 5'd5,
    parameter COEF_9 = 5'd6,
    parameter COEF_8 = 5'd7,
    parameter COEF_7 = 5'd8,
    parameter COEF_6 = 5'd9,
    parameter COEF_5 = 5'd10,
    parameter COEF_4 = 5'd11,
    parameter COEF_3 = 5'd12,
    parameter COEF_2 = 5'd13,
    parameter COEF_1 = 5'd14,
    parameter COEF_0 = 5'd15,
    parameter OUTPUT = 5'd16,
    parameter WAIT_VAL_1 = 5'd17,
    parameter WAIT_VAL_2 = 5'd18,
    parameter WAIT = 5'd19,
    parameter RST_BRAM = 5'd20,
    parameter WAIT_Y = 5'd21
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    // output  wire [3:0]               tap_WE,
    // output  wire                     tap_EN,
    // output  wire [(pDATA_WIDTH-1):0] tap_Di,
    // output  wire [(pADDR_WIDTH-1):0] tap_A,
    // input   wire [(pDATA_WIDTH-1):0] tap_Do,
    output  wire                     tap_we,
    output  wire                     tap_re,
    output  wire [(pADDR_WIDTH-1):0] tap_waddr,
    output  wire [(pADDR_WIDTH-1):0] tap_raddr,
    output  wire [(pDATA_WIDTH-1):0] tap_wdi,
    input   wire [(pDATA_WIDTH-1):0] tap_wdo,

    // bram for data RAM
    // output  wire [3:0]               data_WE,
    // output  wire                     data_EN,
    // output  wire [(pDATA_WIDTH-1):0] data_Di,
    // output  wire [(pADDR_WIDTH-1):0] data_A,
    // input   wire [(pDATA_WIDTH-1):0] data_Do,
    output  wire                     data_we,
    output  wire                     data_re,
    output  wire [(pADDR_WIDTH-1):0] data_waddr,
    output  wire [(pADDR_WIDTH-1):0] data_raddr,
    output  wire [(pDATA_WIDTH-1):0] data_wdi,
    input   wire [(pDATA_WIDTH-1):0] data_wdo,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);


    // write your code here!
    reg [4:0] curr_state, next_state;
    reg [11:0] addr_buf, data_addr_buf, data_raddr_buf;
    reg signed [31:0] write_buf, data_write_buf, read_buf;
    reg read_flag1, read_flag2, WE_flag, data_WE_flag, data_RE_flag;
    reg [31:0] ap_signals, length;
    reg ap_flag, length_flag;
    reg [3:0] SftReg_ptr;
    reg SftReg_full_flag;
    reg [31:0] AddIn_buf, acc;
    reg ss_tready_buf, sm_tvalid_buf;
    reg [31:0] sm_tdata_buf;
    reg [31:0] cnt;
    reg last_data_flag;
    reg finish_flag;
    reg [3:0] RST_BRAM_cnt;
    
    // BRAM
    assign tap_wdi = write_buf;
    assign tap_waddr = addr_buf;
    assign tap_raddr = addr_buf;
    assign tap_we = WE_flag;
    assign tap_re = ~WE_flag;
    assign data_wdi = data_write_buf;
    assign data_waddr =  data_addr_buf;
    assign data_raddr =  data_raddr_buf;
    assign data_we = data_WE_flag;
    assign data_re = data_RE_flag;
    // axi-write
    assign awready = awvalid;
    assign wready = wvalid;
    // axi-read
    assign arready = arvalid;
    assign rvalid = read_flag2;
    assign rdata = read_buf;
    // axi-stream
    assign ss_tready = ss_tready_buf;
    assign sm_tdata = sm_tdata_buf;
    assign sm_tvalid = sm_tvalid_buf;

    always @ (posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            curr_state <= IDLE;
            ap_signals <= 32'h4;
            SftReg_ptr <= 4'h0;
            SftReg_full_flag <= 0;
            AddIn_buf <= 32'd0;
            ss_tready_buf <= 0;
            data_addr_buf <= 12'h000;
            sm_tvalid_buf <= 0;
            sm_tdata_buf <= 32'd0;
            cnt <= 32'd0;
            finish_flag <= 0;
        end
        else begin
            curr_state <= next_state;
            // Coefficient input
            // axilite-write
            if(awvalid) begin
                if(awaddr == 12'h010) begin
                    length_flag <= 1;
                end
                else length_flag <= 0;
                if(awaddr >= 12'h020) begin
                    addr_buf <= (awaddr - 12'h020) / 12'h004;
                end
            end
            if(wvalid) begin
                if(ap_flag) begin
                    ap_signals <= wdata;
                end
                else if(length_flag) begin
                    length <= wdata;
                    length_flag <= 0;
                end
                else begin
                    write_buf <= wdata;
                    WE_flag <= 1;
                end
            end
            //axilite-read
            if(arvalid) begin
                if(araddr == 12'h010) begin
                    length_flag <= 1;
                end
                else length_flag <= 0;
                if(araddr >= 12'h020) begin
                    addr_buf <= (araddr - 12'h020) / 12'h004;
                    WE_flag <= 0;
                end                
            end
            if(rready) begin
                read_flag1 <= 1;
                if(ap_flag) begin
                    read_buf <= ap_signals;
                    //Y[n] reset
                //    ap_signals[5] <= 0;
                end
                else if(length_flag)
                    read_buf <= length;
                else read_buf <= tap_wdo; 
            end
            else read_flag1 <= 0;
            read_flag2 <= read_flag1;

            if(ap_signals[0]) begin
                // ap_start = 0, ap_idle = 0
                ap_signals[0] <= 0;
                ap_signals[2] <= 0;
                // X[n] is ready to accept input
                ap_signals[4] <= 1;
            end
            if(~ap_signals[1]) begin
                if(data_addr_buf == 12'h00A)
                    data_raddr_buf <= 12'h000;
                else
                    data_raddr_buf <= data_addr_buf + 12'h001;
                if(curr_state == INIT_0) begin
                    // FIR
                    acc <= 32'd0;
                    // Data ram write/read
                    data_addr_buf <= 12'h000;
                    data_WE_flag <= 1;
                    data_RE_flag <= 1;
                    data_write_buf <= ss_tdata;
                    ss_tready_buf <= 0;
                    // Initialize output signal
                    sm_tvalid_buf <= 0;
                    // Initialize last data flag
                    last_data_flag <= 0;
                end
                if(curr_state == INIT_1) begin
                    // FIR
                    acc <= 32'd0;
                    // Data ram write/read
                    data_WE_flag <= 1;
                    data_RE_flag <= 1;
                    data_write_buf <= ss_tdata;
                    // Initialize output signal
                    sm_tvalid_buf <= 0;
                end
                else if(curr_state == INIT_2) begin
                    // Tap ram read
                    WE_flag <= 0;
                    addr_buf <= 12'h00a;
                    // Data ram write/read diable
                    data_WE_flag <= 0;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_10) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_9) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_8) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_7) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_6) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_5) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_4) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_3) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_2) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_1) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // BRAM addr
                    addr_buf <= addr_buf - 12'h001;
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;
                end
                else if(curr_state == COEF_0) begin
                    // FIR
                    AddIn_buf <= data_wdo * tap_wdo;
                    acc <= acc + AddIn_buf;
                    // data RAM read disable
                    data_RE_flag <= 0;
                    // BRAM addr
                    if(data_addr_buf == 12'h00a)
                            data_addr_buf <= 12'h000;
                    else    data_addr_buf <= data_addr_buf + 12'h001;

                    ss_tready_buf <= 1;
                end
                else if(curr_state == OUTPUT) begin
                    cnt <= cnt + 32'd1;

                    sm_tdata_buf <= acc + AddIn_buf;
                    sm_tvalid_buf <= 1;

                    ss_tready_buf <= 0;
                end
                else if(curr_state == RST_BRAM) begin
                    //sm_tvalid_buf <= 0;
                    finish_flag <= 0;
                    RST_BRAM_cnt <= RST_BRAM_cnt + 4'd1;
                    // Reset data BRAM value
                    data_WE_flag <= 1;
                    data_write_buf <= 12'h000;
                    if(data_addr_buf == 12'h00a)
                        data_addr_buf <= 12'h000;
                    else
                        data_addr_buf <= data_addr_buf + 12'h001;
                end
                else begin
                
                end
            end
            if(ap_signals[1] == 0 & ap_signals[2] == 1) begin
                // Initialize data BRAM value while coefficient input
                data_WE_flag <= 1;
                data_write_buf <= 12'h000;
                if(data_addr_buf == 12'h00a)
                    data_addr_buf <= 12'h000;
                else
                    data_addr_buf <= data_addr_buf + 12'h001;
            end
            if(cnt == length) begin
                cnt <= 32'd0;
            //    ap_signals[1] <= 1; //ap_done
                ap_signals[2] <= 1;
                finish_flag <= 1;
                RST_BRAM_cnt <= 4'd0;
            end
            if(curr_state == RST_BRAM && RST_BRAM_cnt == 11) begin
                ap_signals[1] <= 1;
            end
        end
    end

    always @ (*) begin
        if(araddr == 12'h000)
            ap_flag = 1;
        else
            ap_flag = 0;
        next_state = 5'dx;
        case (curr_state)
            IDLE: 
                if(ap_signals[0])
                        next_state = START;
                else    next_state = IDLE;
            START:
                if(ss_tvalid)
                        next_state = INIT_0;
                else    next_state = START;
            INIT_0: next_state = INIT_2;
            INIT_1: next_state = INIT_2;
            INIT_2: next_state = COEF_10;
            COEF_10: next_state = COEF_9;
            COEF_9: next_state = COEF_8;
            COEF_8: next_state = COEF_7;
            COEF_7: next_state = COEF_6;
            COEF_6: next_state = COEF_5;
            COEF_5: next_state = COEF_4;
            COEF_4: next_state = COEF_3;
            COEF_3: next_state = COEF_2;
            COEF_2: next_state = COEF_1;
            COEF_1: next_state = COEF_0;
            COEF_0: next_state = OUTPUT;
            OUTPUT:
                next_state = WAIT_VAL_1;
            WAIT_VAL_1:
                next_state <= WAIT_VAL_2;
            WAIT_VAL_2:
                next_state <= WAIT_Y;
            WAIT_Y:
                if(finish_flag)
                    next_state = RST_BRAM;
                else if(!ss_tvalid)
                    next_state = WAIT_Y;
                else if(!ap_signals[5])
                    next_state = WAIT_Y;
                else    next_state = INIT_1;
            RST_BRAM:
                if(RST_BRAM_cnt == 4'd11)
                        next_state = WAIT_Y;
                else    next_state = RST_BRAM;
        endcase
    end

endmodule