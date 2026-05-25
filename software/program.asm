# program.asm - single-core pipeline smoke test
#
# Matches tb/program.hex. This test exercises ALU, store, load, load-use branch,
# and jump flush behavior.

    addi x1, x0, 10      # x1 = 10
    addi x2, x0, 20      # x2 = 20
    add  x3, x1, x2      # x3 = 30
    sw   x3, 0(x0)       # mem[0] = 30
    lw   x4, 0(x0)       # x4 = 30
    beq  x3, x4, pass    # load-use branch must be handled
fail:
    jal  x0, fail
pass:
    addi x5, x0, 1       # pass marker
halt:
    jal  x0, halt
