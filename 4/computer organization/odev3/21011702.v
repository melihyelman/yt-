module RiscV_SingleCycle(
    input clk,
    input reset,
    output reg [31:0] pc,
    output reg [31:0] alu_result,
    output [31:0] write_data,
    input [31:0] read_data
);

    // Define memory
    reg [31:0] memory[0:1023]; // 1K words of memory
    reg [31:0] instruction_memory[0:255]; // 256 words of instruction memory

    // Register and next PC logic
    reg [31:0] next_pc;
    reg [31:0] registers[0:31];

    // Decode fields from instruction
    wire [31:0] instruction = instruction_memory[pc >> 2]; // Fetch instruction based on PC
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd = instruction[11:7];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    wire [31:0] rs1_data = registers[rs1];
    wire [31:0] rs2_data = registers[rs2];

    // Immediate value processing
    wire signed [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]};
    wire signed [31:0] imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    wire signed [31:0] imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    wire signed [31:0] sign_extended_imm = (opcode == 7'b0000011 || opcode == 7'b0010011) ? imm_i : imm_s;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 0;
        end else begin
            pc <= next_pc;
        end
    end

    // ALU operation
    reg [31:0] alu_out;
    always @(*) begin
        case (opcode)
            7'b0110011: // R-type operations
                case (funct3)
                    3'b000: alu_out = (funct7 == 7'b0000000) ? rs1_data + rs2_data : rs1_data - rs2_data;
                    3'b101: alu_out = (funct7 == 7'b0100000) ? $signed(rs1_data) >>> rs2_data[4:0] : rs1_data >> rs2_data[4:0]; // Shift operations
                    3'b110: alu_out = rs1_data | rs2_data;
                    3'b111: alu_out = rs1_data & rs2_data;
                    3'b010: alu_out = ($signed(rs1_data) < $signed(rs2_data)) ? 1 : 0;
                endcase
            7'b0010011: // I-type ALU operations
                case (funct3)
                    3'b000: alu_out = rs1_data + sign_extended_imm; // addi
                    3'b110: alu_out = rs1_data | sign_extended_imm;
                    3'b111: alu_out = rs1_data & sign_extended_imm;
                    3'b010: alu_out = ($signed(rs1_data) < $signed(sign_extended_imm)) ? 1 : 0;
                endcase
            7'b0000011: // LW
                alu_out = rs1_data + sign_extended_imm;
            7'b0100011: // SW
                alu_out = rs1_data + sign_extended_imm;
            7'b1101111: // JAL
                alu_out = pc + {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            7'b1100011: // BEQ and other branches
                case (funct3)
                    3'b000: // beq
                        if (rs1_data == rs2_data) begin
                            alu_out = pc + imm_b;
                        end else begin
                            alu_out = pc + 4;
                        end
                    default: alu_out = pc + 4;
                endcase
            default: alu_out = pc + 4; // Default case for other instructions
        endcase
    end

    // Update alu_result on clock edge to capture the computed ALU output
    always @(posedge clk) begin
        alu_result <= alu_out;
    end

    // Write data to registers and handle load/store
    assign write_data = registers[rd];
    always @(posedge clk) begin
        if (!reset && rd != 0) begin
            if (opcode == 7'b0000011) // LW
                registers[rd] <= memory[alu_out[9:0]]; // Read from memory
            else if (opcode == 7'b0010011) // I-type instructions
                registers[rd] <= alu_out;
            else if (opcode == 7'b0110011) // R-type instructions
                registers[rd] <= alu_out;
        end
        if (opcode == 7'b0100011) // SW
            memory[alu_out[9:0]] <= rs2_data; // Write to memory
    end

    // Update next_pc
    always @(*) begin
        case (opcode)
            7'b1101111: // JAL
                next_pc = alu_out;
            7'b1100011: // BEQ and other branches
                if ((funct3 == 3'b000 && rs1_data == rs2_data) || 
                    (funct3 == 3'b001 && rs1_data != rs2_data)) begin
                    next_pc = pc + {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                end else begin
                    next_pc = pc + 4;
                end
            default:
                next_pc = pc + 4; // Default case for other instructions
        endcase
    end

    always @(posedge clk) begin
        $display("Time: %t, PC: %d, Next PC: %d, Opcode: %b, Funct3: %b, RS1 Data: %d, RS2 Data: %d, ALU Result: %d",
                 $time, pc, next_pc, opcode, funct3, rs1_data, rs2_data, alu_result);
        if (opcode == 7'b0100011) begin
            $display("SW: memory[%d] <= %d", alu_out[9:0], rs2_data);
        end
    end


    integer i;
    initial begin
        // Initialize ARR array
        memory[0] = 3; memory[1] = 7; memory[2] = 2; memory[3] = 6;
        memory[4] = 5; memory[5] = 4; memory[6] = 1; memory[7] = 1000;
        memory[8] = 999; memory[9] = 25; memory[10] = 90; memory[11] = 100;
        memory[12] = 30; memory[13] = 20; memory[14] = 10; memory[15] = 200;
        memory[16] = 3300; memory[17] = 250; memory[18] = 12; memory[19] = 75;

        // Initialize COUNT array
        memory[20] = 17; memory[21] = 13; memory[22] = 18; memory[23] = 14;
        memory[24] = 15; memory[25] = 16; memory[26] = 19; memory[27] = 1;
        memory[28] = 2; memory[29] = 9; memory[30] = 6; memory[31] = 5;
        memory[32] = 8; memory[33] = 10; memory[34] = 12; memory[35] = 4;
        memory[36] = 0; memory[37] = 3; memory[38] = 11; memory[39] = 7;

        // Reset RESULT array
        for (i = 40; i < 60; i = i + 1) begin
            memory[i] = 0;
        end
    end

endmodule
