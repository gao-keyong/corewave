`include "defines.svh"

module openmips (

    input logic clk,
    input logic rst,

    input  logic [`RegBus] rom_data_i,
    output logic [`RegBus] rom_addr_o,
    output logic           rom_ce_o

);

    logic [`InstAddrBus] pc;
    logic [`InstAddrBus] id_pc_i;
    logic [`InstBus] id_inst_i;

    //连接译码阶段ID模块的输出与ID/EX模块的输入
    logic [`AluOpBus] id_aluop_o;
    logic [`AluSelBus] id_alusel_o;
    logic [`RegBus] id_reg1_o;
    logic [`RegBus] id_reg2_o;
    logic id_wreg_o;
    logic [`RegAddrBus] id_wd_o;
    logic id_is_in_delayslot_o;
    logic [`RegBus] id_link_address_o;

    //连接ID/EX模块的输出与执行阶段EX模块的输入
    logic [`AluOpBus] ex_aluop_i;
    logic [`AluSelBus] ex_alusel_i;
    logic [`RegBus] ex_reg1_i;
    logic [`RegBus] ex_reg2_i;
    logic ex_wreg_i;
    logic [`RegAddrBus] ex_wd_i;
    logic ex_is_in_delayslot_i;
    logic [`RegBus] ex_link_address_i;

    //连接执行阶段EX模块的输出与EX/MEM模块的输入
    logic ex_wreg_o;
    logic [`RegAddrBus] ex_wd_o;
    logic [`RegBus] ex_wdata_o;
    logic [`RegBus] ex_hi_o;
    logic [`RegBus] ex_lo_o;
    logic ex_whilo_o;

    //连接EX/MEM模块的输出与访存阶段MEM模块的输入
    logic mem_wreg_i;
    logic [`RegAddrBus] mem_wd_i;
    logic [`RegBus] mem_wdata_i;
    logic [`RegBus] mem_hi_i;
    logic [`RegBus] mem_lo_i;
    logic mem_whilo_i;

    //连接访存阶段MEM模块的输出与MEM/WB模块的输入
    logic mem_wreg_o;
    logic [`RegAddrBus] mem_wd_o;
    logic [`RegBus] mem_wdata_o;
    logic [`RegBus] mem_hi_o;
    logic [`RegBus] mem_lo_o;
    logic mem_whilo_o;

    //连接MEM/WB模块的输出与回写阶段的输入	
    logic wb_wreg_i;
    logic [`RegAddrBus] wb_wd_i;
    logic [`RegBus] wb_wdata_i;
    logic [`RegBus] wb_hi_i;
    logic [`RegBus] wb_lo_i;
    logic wb_whilo_i;

    //连接译码阶段ID模块与通用寄存器Regfile模块
    logic reg1_read;
    logic reg2_read;
    logic [`RegBus] reg1_data;
    logic [`RegBus] reg2_data;
    logic [`RegAddrBus] reg1_addr;
    logic [`RegAddrBus] reg2_addr;

    //连接执行阶段与hilo模块的输出，读取HI、LO寄存器
    logic [`RegBus] hi;
    logic [`RegBus] lo;

    //连接执行阶段与ex_reg模块，用于多周期的MADD、MADDU、MSUB、MSUBU指令
    logic [`DoubleRegBus] hilo_temp_o;
    logic [1:0] cnt_o;

    logic [`DoubleRegBus] hilo_temp_i;
    logic [1:0] cnt_i;

    logic [`DoubleRegBus] div_result;
    logic div_ready;
    logic [`RegBus] div_opdata1;
    logic [`RegBus] div_opdata2;
    logic div_start;
    logic div_annul;
    logic signed_div;

    logic is_in_delayslot_i;
    logic is_in_delayslot_o;
    logic next_inst_in_delayslot_o;
    logic id_branch_flag_o;
    logic [`RegBus] branch_target_address;

    logic [5:0] stall;
    logic stallreq_from_id;
    logic stallreq_from_ex;

    //pc_reg例化
    pc_reg pc_reg0 (
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .branch_flag_i(id_branch_flag_o),
        .branch_target_address_i(branch_target_address),
        .pc(pc),
        .ce(rom_ce_o)

    );

    assign rom_addr_o = pc;

    //IF/ID模块例化
    if_id if_id0 (
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .if_pc(pc),
        .if_inst(rom_data_i),
        .id_pc(id_pc_i),
        .id_inst(id_inst_i)
    );

    //译码阶段ID模块
    id id0 (
        .rst(rst),
        .pc_i(id_pc_i),
        .inst_i(id_inst_i),

        .reg1_data_i(reg1_data),
        .reg2_data_i(reg2_data),

        //处于执行阶段的指令要写入的目的寄存器信息
        .ex_wreg_i(ex_wreg_o),
        .ex_wdata_i(ex_wdata_o),
        .ex_wd_i(ex_wd_o),

        //处于访存阶段的指令要写入的目的寄存器信息
        .mem_wreg_i(mem_wreg_o),
        .mem_wdata_i(mem_wdata_o),
        .mem_wd_i(mem_wd_o),

        .is_in_delayslot_i(is_in_delayslot_i),

        //送到regfile的信息
        .reg1_read_o(reg1_read),
        .reg2_read_o(reg2_read),

        .reg1_addr_o(reg1_addr),
        .reg2_addr_o(reg2_addr),

        //送到ID/EX模块的信息
        .aluop_o(id_aluop_o),
        .alusel_o(id_alusel_o),
        .reg1_o(id_reg1_o),
        .reg2_o(id_reg2_o),
        .wd_o(id_wd_o),
        .wreg_o(id_wreg_o),

        .next_inst_in_delayslot_o(next_inst_in_delayslot_o),
        .branch_flag_o(id_branch_flag_o),
        .branch_target_address_o(branch_target_address),
        .link_addr_o(id_link_address_o),

        .is_in_delayslot_o(id_is_in_delayslot_o),

        .stallreq(stallreq_from_id)
    );

    //通用寄存器Regfile例化
    regfile regfile1 (
        .clk(clk),
        .rst(rst),
        .we(wb_wreg_i),
        .waddr(wb_wd_i),
        .wdata(wb_wdata_i),
        .re1(reg1_read),
        .raddr1(reg1_addr),
        .rdata1(reg1_data),
        .re2(reg2_read),
        .raddr2(reg2_addr),
        .rdata2(reg2_data)
    );

    //ID/EX模块
    id_ex id_ex0 (
        .clk(clk),
        .rst(rst),

        .stall(stall),

        //从译码阶段ID模块传递的信息
        .id_aluop(id_aluop_o),
        .id_alusel(id_alusel_o),
        .id_reg1(id_reg1_o),
        .id_reg2(id_reg2_o),
        .id_wd(id_wd_o),
        .id_wreg(id_wreg_o),
        .id_link_address(id_link_address_o),
        .id_is_in_delayslot(id_is_in_delayslot_o),
        .next_inst_in_delayslot_i(next_inst_in_delayslot_o),

        //传递到执行阶段EX模块的信息
        .ex_aluop(ex_aluop_i),
        .ex_alusel(ex_alusel_i),
        .ex_reg1(ex_reg1_i),
        .ex_reg2(ex_reg2_i),
        .ex_wd(ex_wd_i),
        .ex_wreg(ex_wreg_i),
        .ex_link_address(ex_link_address_i),
        .ex_is_in_delayslot(ex_is_in_delayslot_i),
        .is_in_delayslot_o(is_in_delayslot_i)
    );

    //EX模块
    ex ex0 (
        .rst(rst),

        //送到执行阶段EX模块的信息
        .aluop_i(ex_aluop_i),
        .alusel_i(ex_alusel_i),
        .reg1_i(ex_reg1_i),
        .reg2_i(ex_reg2_i),
        .wd_i(ex_wd_i),
        .wreg_i(ex_wreg_i),
        .hi_i(hi),
        .lo_i(lo),

        .wb_hi_i(wb_hi_i),
        .wb_lo_i(wb_lo_i),
        .wb_whilo_i(wb_whilo_i),
        .mem_hi_i(mem_hi_o),
        .mem_lo_i(mem_lo_o),
        .mem_whilo_i(mem_whilo_o),

        .hilo_temp_i(hilo_temp_i),
        .cnt_i(cnt_i),

        .div_result_i(div_result),
        .div_ready_i (div_ready),

        .link_address_i(ex_link_address_i),
        .is_in_delayslot_i(ex_is_in_delayslot_i),

        //EX模块的输出到EX/MEM模块信息
        .wd_o(ex_wd_o),
        .wreg_o(ex_wreg_o),
        .wdata_o(ex_wdata_o),

        .hi_o(ex_hi_o),
        .lo_o(ex_lo_o),
        .whilo_o(ex_whilo_o),

        .hilo_temp_o(hilo_temp_o),
        .cnt_o(cnt_o),

        .div_opdata1_o(div_opdata1),
        .div_opdata2_o(div_opdata2),
        .div_start_o  (div_start),
        .signed_div_o (signed_div),

        .stallreq(stallreq_from_ex)

    );

    //EX/MEM模块
    ex_mem ex_mem0 (
        .clk(clk),
        .rst(rst),

        .stall(stall),

        //来自执行阶段EX模块的信息	
        .ex_wd(ex_wd_o),
        .ex_wreg(ex_wreg_o),
        .ex_wdata(ex_wdata_o),
        .ex_hi(ex_hi_o),
        .ex_lo(ex_lo_o),
        .ex_whilo(ex_whilo_o),

        .hilo_i(hilo_temp_o),
        .cnt_i (cnt_o),

        //送到访存阶段MEM模块的信息
        .mem_wd(mem_wd_i),
        .mem_wreg(mem_wreg_i),
        .mem_wdata(mem_wdata_i),
        .mem_hi(mem_hi_i),
        .mem_lo(mem_lo_i),
        .mem_whilo(mem_whilo_i),

        .hilo_o(hilo_temp_i),
        .cnt_o (cnt_i)

    );

    //MEM模块例化
    mem mem0 (
        .rst(rst),

        //来自EX/MEM模块的信息	
        .wd_i(mem_wd_i),
        .wreg_i(mem_wreg_i),
        .wdata_i(mem_wdata_i),
        .hi_i(mem_hi_i),
        .lo_i(mem_lo_i),
        .whilo_i(mem_whilo_i),

        //送到MEM/WB模块的信息
        .wd_o(mem_wd_o),
        .wreg_o(mem_wreg_o),
        .wdata_o(mem_wdata_o),
        .hi_o(mem_hi_o),
        .lo_o(mem_lo_o),
        .whilo_o(mem_whilo_o)
    );

    //MEM/WB模块
    mem_wb mem_wb0 (
        .clk(clk),
        .rst(rst),

        .stall(stall),

        //来自访存阶段MEM模块的信息	
        .mem_wd(mem_wd_o),
        .mem_wreg(mem_wreg_o),
        .mem_wdata(mem_wdata_o),
        .mem_hi(mem_hi_o),
        .mem_lo(mem_lo_o),
        .mem_whilo(mem_whilo_o),

        //送到回写阶段的信息
        .wb_wd(wb_wd_i),
        .wb_wreg(wb_wreg_i),
        .wb_wdata(wb_wdata_i),
        .wb_hi(wb_hi_i),
        .wb_lo(wb_lo_i),
        .wb_whilo(wb_whilo_i)

    );

    hilo_reg hilo_reg0 (
        .clk(clk),
        .rst(rst),

        //写端口
        .we  (wb_whilo_i),
        .hi_i(wb_hi_i),
        .lo_i(wb_lo_i),

        //读端口1
        .hi_o(hi),
        .lo_o(lo)
    );

    ctrl ctrl0 (
        .rst(rst),

        .stallreq_from_id(stallreq_from_id),

        //来自执行阶段的暂停请求
        .stallreq_from_ex(stallreq_from_ex),

        .stall(stall)
    );

    div div0 (
        .clk(clk),
        .rst(rst),

        .signed_div_i(signed_div),
        .opdata1_i(div_opdata1),
        .opdata2_i(div_opdata2),
        .start_i(div_start),
        .annul_i(1'b0),

        .result_o(div_result),
        .ready_o (div_ready)
    );

endmodule
