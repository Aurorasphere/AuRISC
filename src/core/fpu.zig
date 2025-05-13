pub const FPU = struct {
    fp_regs: [32]u64, 
    
}

const fext_instrs = enum{
// F-Extension: Floating point extensions
    fadd, // Floating point addition
    fsub, // Floating point subtraction
    fmul, // Floating point multilication
    fdiv, // Floating point division
    fsqrt, // Floating point square root
    fcmp, // Floating point compare
    ftint, // Floating point to Signed integer
    ftuint, // Floating point to Unsigned interger
    fmvi, // Move Floating point bit to integer
    imvf, // Move integer bit to floating point
}

