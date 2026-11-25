/*
 * SPDX-License-Identifier: 0BSD
 *
 * <architecture/arm64/fenv.h>, written for the open SDK.
 *
 * Libm-2026, the newest public Libm, only has the <fenv.h> of 32-bit ARM
 * (Source/ARM/fenv.h), which describes the FPSCR of VFP. On arm64 the same
 * state is split into the FPSR (status) and the FPCR (control) registers
 * (Arm Architecture Reference Manual for A-profile, "FPSR" and "FPCR").
 * The exception and rounding constants, fexcept_t and the name of the
 * default environment are those of Libm/Source/ARM/fenv.h: the cumulative
 * exception bits are bits 0-4 of the FPSR and the rounding mode is bits
 * 23:22 of the FPCR, the same positions as in the FPSCR. fenv_t has the
 * size of that header's fenv_t (16 bytes, which is the size of the two
 * 64-bit registers FPSR and FPCR); a larger type than the one that the
 * library fills in is harmless. The field names __fpsr and __fpcr are those
 * of the ARM NEON state in xnu (osfmk/mach/arm/_structs.h, struct
 * __darwin_arm_neon_state64, where they are 32 bits wide); they are
 * 64 bits wide here so that the type has the size of Libm's fenv_t.
 *
 * Only the interface of C99/C11 7.6 is declared, plus FE_DFL_ENV as in the
 * 32-bit header.
 */
#ifndef __ARCHITECTURE_ARM64_FENV_H__
#define __ARCHITECTURE_ARM64_FENV_H__

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    unsigned long long __fpsr;  /* status: cumulative exception flags */
    unsigned long long __fpcr;  /* control: rounding mode, trap enables */
} fenv_t;

typedef unsigned short fexcept_t;

/* FPSR bits IOC, DZC, OFC, UFC, IXC */
#define FE_INVALID          0x0001
#define FE_DIVBYZERO        0x0002
#define FE_OVERFLOW         0x0004
#define FE_UNDERFLOW        0x0008
#define FE_INEXACT          0x0010
#define FE_ALL_EXCEPT       0x001F

/* FPCR.RMode */
#define FE_TONEAREST        0x00000000
#define FE_UPWARD           0x00400000
#define FE_DOWNWARD         0x00800000
#define FE_TOWARDZERO       0x00C00000

extern const fenv_t _FE_DFL_ENV;
#define FE_DFL_ENV (&_FE_DFL_ENV)

extern int feclearexcept(int __excepts);
extern int fegetexceptflag(fexcept_t *__flagp, int __excepts);
extern int feraiseexcept(int __excepts);
extern int fesetexceptflag(const fexcept_t *__flagp, int __excepts);
extern int fetestexcept(int __excepts);

extern int fegetround(void);
extern int fesetround(int __round);

extern int fegetenv(fenv_t *__envp);
extern int feholdexcept(fenv_t *__envp);
extern int fesetenv(const fenv_t *__envp);
extern int feupdateenv(const fenv_t *__envp);

#ifdef __cplusplus
}
#endif

#endif /* __ARCHITECTURE_ARM64_FENV_H__ */
