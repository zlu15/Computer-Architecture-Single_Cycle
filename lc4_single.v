/* TODO: name and PennKeys of all group members here
 *
 * lc4_single.v
 * Implements a single-cycle data path
 *
 */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // Main clock
    input  wire        rst,                // Global reset
    input  wire        gwe,                // Global we for single-step clock
   
    output wire [15:0] o_cur_pc,           // Address to read from instruction memory
    input  wire [15:0] i_cur_insn,         // Output of instruction memory
    output wire [15:0] o_dmem_addr,        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
    input  wire [15:0] i_cur_dmem_data,    // Output of data memory
    output wire        o_dmem_we,          // Data memory write enable
    output wire [15:0] o_dmem_towrite,     // Value to write to data memory

    // Testbench signals are used by the testbench to verify the correctness of your datapath.
    // Many of these signals simply export internal processor state for verification (such as the PC).
    // Some signals are duplicate output signals for clarity of purpose.
    //
    // Don't forget to include these in your schematic!

    output wire [1:0]  test_stall,         // Testbench: is this a stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc,        // Testbench: program counter
    output wire [15:0] test_cur_insn,      // Testbench: instruction bits
    output wire        test_regfile_we,    // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel,  // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data,  // Testbench: value to write into the register file
    output wire        test_nzp_we,        // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits,  // Testbench: value to write to NZP bits
    output wire        test_dmem_we,       // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr,     // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data,     // Testbench: value read/writen from/to memory
   
    input  wire [7:0]  switch_data,        // Current settings of the Zedboard switches
    output wire [7:0]  led_data            // Which Zedboard LEDs should be turned on?
    );

   // By default, assign LEDs to display switch inputs to avoid warnings about
   // disconnected ports. Feel free to use this for debugging input/output if
   // you desire.
   assign led_data = switch_data;

   
   /* DO NOT MODIFY THIS CODE */
   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   assign test_stall = 2'b0; 

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   /* END DO NOT MODIFY THIS CODE */
   /*******************************
    * TODO: INSERT YOUR CODE HERE *
    *******************************/
    //assign o_cur_pc = pc;
    //decoder for the singlecycle datapath
    wire [2:0] r1sel, r2sel, wsel;
    wire r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;
    lc4_decoder decoder_0(.insn(i_cur_insn),                         // instruction
                         .r1sel(r1sel),                             // rs
                         .r1re(r1re),                               // does this instruction read from rs?
                         .r2sel(r2sel),                             // rt
                         .r2re(r2re),                               // does this instruction read from rt?
                         .wsel(wsel),                               // rd
                         .regfile_we(regfile_we),                   // does this instruction write to rd?
                         .nzp_we(nzp_we),                           // does this instruction write the NZP bits?
                         .select_pc_plus_one(select_pc_plus_one),   // write PC+1 to the regfile?
                         .is_load(is_load),                         // is this a load instruction?
                         .is_store(is_store),                       // is this a store instruction?
                         .is_branch(is_branch),                     // is this a branch instruction?
                         .is_control_insn(is_control_insn)          // is this a control instruction (JSR, JSRR, RTI, JMPR, JMP, TRAP)?
                         );
    //register file for the singlecycle datapath                     
    wire [15:0] o_rs_data, o_rt_data;                 
    lc4_regfile #(16) regfile_0 (.clk(clk),
                                .gwe(gwe),
                                .rst(rst),
                                .i_rs(r1sel),              // rs selector
                                .o_rs_data(o_rs_data),     // rs contents
                                .i_rt(r2sel),              // rt selector
                                .o_rt_data(o_rt_data),     // rt contents
                                .i_rd(wsel),               // rd selector
                                .i_wdata(alu_or_pc_plus_one_or_load), // data to write
                                .i_rd_we(regfile_we)       // write enable
                                );
    
    //ALU unit for the singlecycle datapath
    wire [15:0] alu_result;                            
    lc4_alu alu_0 (.i_insn(i_cur_insn),
                  .i_pc(pc),
                  .i_r1data(o_rs_data),
                  .i_r2data(o_rt_data),
                  .o_result(alu_result));  
    
    //pc+1 for the singlecycle datapath                  
    wire [15:0] pc_plus_one;                      
    cla16 cla16_pc (.a(pc), 
                    .b(16'b1),
                    .cin(1'b0),
                    .sum(pc_plus_one)); 
    //select wether it should be pc+1 or alu result (the mux right after ALU)              
    wire [15:0] alu_or_pc_plus_one;
    assign alu_or_pc_plus_one = (select_pc_plus_one == 1'b1) ? pc_plus_one : alu_result;
    
                   
    //the mux after alu_or_pc_plus_one
    wire [15:0] alu_or_pc_plus_one_or_load ;  
    assign alu_or_pc_plus_one_or_load = ((is_load == 1'b1)) ? i_cur_dmem_data : alu_or_pc_plus_one;
    
    //NZP registers write in
    wire [2:0] nzp_reg_in, nzp_reg_out;
    Nbit_reg #(3) n_reg (.in(nzp_reg_in), .out(nzp_reg_out), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));
    assign nzp_reg_in = ($signed(alu_or_pc_plus_one_or_load) > $signed(16'b0) ) ? 3'b001:
                        ($signed(alu_or_pc_plus_one_or_load) == $signed(16'b0) ) ? 3'b010:
                        ($signed(alu_or_pc_plus_one_or_load) < $signed(16'b0) ) ? 3'b100:3'b000;

    wire br_logic_output, br_logic_output_temp;
    //branch logic    
    assign br_logic_output_temp = ((i_cur_insn[11:9] == 3'b001) & (nzp_reg_out == 3'b001)) |
                                  (((i_cur_insn[11:9] == 3'b010) & (nzp_reg_out == 3'b010))) |
                                  ((i_cur_insn[11:9] == 3'b011) & ((nzp_reg_out == 3'b001) | (nzp_reg_out == 3'b010))) |
                                  ((i_cur_insn[11:9] == 3'b100) & (nzp_reg_out == 3'b100)) |
                                  ((i_cur_insn[11:9] == 3'b101) & ((nzp_reg_out == 3'b100) | (nzp_reg_out == 3'b001))) |
                                  ((i_cur_insn[11:9] == 3'b110) & ((nzp_reg_out == 3'b100) | (nzp_reg_out == 3'b010))) |
                                  ((i_cur_insn[11:9] == 3'b111) &((nzp_reg_out == 3'b100) | (nzp_reg_out == 3'b010) | (nzp_reg_out == 1'b001))) |
                                  is_control_insn;
    assign br_logic_output = (is_branch == 1'b1 | is_control_insn == 1'b1) ? br_logic_output_temp : 1'b0;                               
    assign next_pc = (br_logic_output == 1'b1) ? alu_result : pc_plus_one;  
      
    //update PC address
    assign o_cur_pc = pc;
    
    // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
    assign o_dmem_addr = (is_store | is_load) ? alu_or_pc_plus_one : 16'b0;
    // This is the logic part for store instruction. It enable the write function in memory and get the data from rt in register.
    // The write address has already determined above
    assign o_dmem_we = is_store;
    assign o_dmem_towrite = o_rt_data;

    
    
    
    
    
    assign test_cur_pc = pc; 
    assign test_cur_insn = i_cur_insn;
    assign test_regfile_we = regfile_we;
    assign test_regfile_wsel = wsel;
    assign test_regfile_data = alu_or_pc_plus_one_or_load;
    assign test_nzp_we = nzp_we;
    assign test_nzp_new_bits = nzp_reg_in;    
    assign test_dmem_we = is_store;
    assign test_dmem_addr = o_dmem_addr;
    assign test_dmem_data = (is_load) ? alu_or_pc_plus_one_or_load:
                            (is_store) ? o_rt_data:16'b0;
    //select wether it should be pc+1 or other pc address for (jsrr, jsr, rti, jmpr,jmp,trap)   
   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    * 
    * To disable the entire block add the statement
    * `define NDEBUG
    * to the top of your file.  We also define this symbol
    * when we run the grading scripts.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecial.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      $display();
   end
`endif
endmodule
