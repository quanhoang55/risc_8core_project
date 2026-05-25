# system_program.asm - 8-core shared-memory pipeline demo
#
# Every core runs the same program. The shared bus/arbiter must serialize the
# three memory transactions from each core: SW, LW, SW.

    addi x1, x0, 42      # x1 = 42
    sw   x1, 0(x0)       # mem[0] = 42
    lw   x2, 0(x0)       # x2 = mem[0]
    addi x3, x0, 99      # completion marker
    sw   x3, 4(x0)       # mem[1] = 99
halt:
    jal  x0, halt        # halt loop
