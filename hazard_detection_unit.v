`timescale 1ns / 1ps
// ============================================================================
// hazard_detection_unit.v   ("stall controller")
// The one hazard forwarding CANNOT fix: LOAD-USE.
// A lw produces its data only at the end of MEM, but the very next instruction
// needs it at the start of its EX. So we insert exactly ONE bubble; after that,
// the MEM-EX forwarding path delivers the loaded value.
//
// Detection (done in ID, looking at the instruction currently in ID/EX):
//   stall  <=  ID/EX.MemRead  AND
//              ( ID/EX.rt == IF/ID.rs  OR  ID/EX.rt == IF/ID.rt )
//
// On stall:  freeze the PC and the IF/ID register (re-fetch / re-decode the
//            same two instructions next cycle) and push a bubble into ID/EX.
// ============================================================================
module hazard_detection_unit (
    input            id_ex_mem_read,
    input      [4:0] id_ex_rt,
    input      [4:0] if_id_rs,
    input      [4:0] if_id_rt,
    output           stall          // 1 => insert one bubble this cycle
);
    assign stall = id_ex_mem_read &&
                   ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt));
endmodule
