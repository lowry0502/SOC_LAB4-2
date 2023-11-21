`timescale 1ns / 1ps
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
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
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);


    // write your code here!
reg [1:0] state;
reg [1:0] stream_st;
reg [1:0] tap_ram_st;
reg [1:0] data_ram_st;
reg [1:0] ap_start;
reg [3:0] ap_crl;
reg [11:0] sh_addr;
reg [11:0] shw_addr;
reg [31:0] sh_data;
reg [1:0] shift_st;
reg [1:0] fir_st;
reg [31:0] acc;
reg signed [31:0] acc2;
reg [31:0] flag;
reg k;
reg bramrst;
integer i;

parameter IDLE = 2'b00;
parameter READ = 2'b01;
parameter WRITE = 2'b10;
parameter SHIFT = 2'b11;

always @(posedge axis_clk or negedge axis_rst_n ) begin
    if (!axis_rst_n) begin
    //    $display("reset");
        state <= IDLE;
        tap_ram_st <= IDLE;
        stream_st <= IDLE;
        data_ram_st <= IDLE;
        shift_st <= IDLE;
        ap_start <= 0;
        ap_crl <= 4'b0010;
        fir_st <= IDLE;
        k <= 0;
        bramrst <= 1 ;
    end else begin
        case (state)
            IDLE: begin
                if (awvalid) begin
                    state <= READ;
                //    $display("read tap");
                end 
                if (arvalid) begin
                    state <= WRITE;
                end
            end
            READ: begin
                tap_ram_st <= WRITE;
                //$display("data input: %d", wdata);
                state <= IDLE;
            end
            WRITE: begin
                if (rready) begin
                    tap_ram_st <= READ;
                end
                //$display("123");
                state <= IDLE; 
            end
        endcase
    end
end

always @(posedge axis_clk) begin    //ap_start receive
    if(state == READ && tap_A == 0) begin
        ap_start <= wdata;
        if(wdata) begin
            ap_crl[1] <= 0;
        end
        //$display("ap: %b",ap_crl);
    end
end

assign wready = ( wvalid && state == IDLE); 
assign tap_EN = (tap_ram_st == READ || tap_ram_st == WRITE || stream_st == SHIFT && !state==IDLE);
assign tap_WE = (tap_ram_st == WRITE && !ap_start) ? ( (awaddr == 0) ? 4'b0100 : 4'b1111 ): 4'b0000;
assign tap_Di = (!tap_A == 0) ? wdata : ap_crl;
assign tap_A =  (!ap_start) ? (tap_ram_st == WRITE) ? ( (awaddr >= 12'h1f) ? (awaddr - 12'h1f)<<2 : awaddr) : (araddr >= 12'h1f) ? ( araddr-12'h1f )<<2 : araddr : data_A;

assign rdata = (!araddr == 0) ? tap_Do : ap_crl;
assign rvalid = ((tap_ram_st == READ && state == WRITE) || araddr == 0);


always @(posedge axis_clk  && (ss_tvalid && ap_start )  || bramrst) begin
    case (stream_st)
        IDLE: begin
            if(bramrst) begin
                stream_st <= SHIFT;
            end    
            else if (ss_tvalid) begin
                stream_st <= SHIFT;
            end
            sh_addr <= 12'd10<<2;
            shw_addr <=12'd11<<2;
            i <= 0;
            data_ram_st <= IDLE;
        end
        READ: begin
            data_ram_st <= WRITE;
            stream_st <= IDLE;
            fir_st <= WRITE;
            acc <= 0;
            acc2 <=0;
            flag <= 0;
            if(ss_tlast) begin
                ap_crl[1] <= 1;
                ap_crl[2] <= 1;    
            end
        end
        WRITE: begin
            stream_st <= READ;
            k <= 1;
            if(!bramrst) begin
                k <= 1;
            end
            else begin
                bramrst <= 0;
            end
        end
        SHIFT: begin
        //    $display("shifting");
        end
    endcase
end
always @(posedge axis_clk  && stream_st == SHIFT ) begin
    //$display("asdf");
    case (shift_st)
        IDLE: begin
           // $display("IDLE");
            if(sh_addr == 12'd0<<2) begin
                stream_st <= WRITE;
            end
            else if(i == 0) begin
                shift_st <= READ;
                sh_addr <= sh_addr - 1;
                shw_addr <= shw_addr -1;
                if(flag == 3) begin
                    if(acc) begin
                        acc2 <= acc2 + acc;
                    end
                    flag <= 0;
                end
                else begin
                    flag <= flag + 1;
                end
            //    $display("acc = %d acc2 = %d flag = %d sh_addr = %d",acc, acc2,flag,sh_addr>>2);
            end
            else if(i == 1) begin
                shift_st <= WRITE;
            end
            else begin
                i <= i - 3;
            end
        end
        READ: begin
        //$display("read i=%d read address=%d data=%d",i,data_A>>2,data_Do);
        //$display("read");
            if(i == 1) begin
                shift_st <= IDLE;
            end else begin
                i = i + 1;
            end
            sh_data <= data_Do;
        end
        WRITE: begin
        //$display("write");
            if(i == 2) begin
                shift_st <= IDLE;
                i <= 0;
                acc <= sh_data*tap_Do;
            //    acc2 = acc2 + 2;
            //    $display("acc = %d",acc);
            end else begin
                i = i + 1;
                
            //    $display("tap_a = %d TAP_DO = %d data_Do = %d acc = %d",(tap_A+1)>>2,tap_Do,sh_data, acc);
            end
        end
    endcase
end
assign ss_tready = (stream_st == IDLE && fir_st == WRITE && ap_start && !bramrst);
assign data_EN = (data_ram_st == READ || data_ram_st == WRITE || ( stream_st == SHIFT && (shift_st != IDLE)));
assign data_WE = (shift_st == WRITE || data_ram_st == WRITE) ? 4'b1111 : 4'b0000;
assign data_Di = (stream_st == SHIFT)? (bramrst) ? 0 : sh_data : ss_tdata;
assign data_A = (stream_st == SHIFT)? ( (shift_st != READ) ? shw_addr : sh_addr ) : 0;


assign sm_tdata = acc2;
assign sm_tvalid = (sm_tready && stream_st == WRITE && k);
assign sm_tlast = (ap_crl[1]);


endmodule
        
