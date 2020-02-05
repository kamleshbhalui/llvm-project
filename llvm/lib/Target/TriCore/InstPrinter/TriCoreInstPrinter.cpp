//===-- TriCoreInstPrinter.cpp - Convert TriCore MCInst to asm syntax -----===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This class prints an TriCore MCInst to a .s file.
//
//===----------------------------------------------------------------------===//

#include "TriCoreInstPrinter.h"
#include "Utils/TriCoreBaseInfo.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/FormattedStream.h"

using namespace llvm;

#define DEBUG_TYPE "asm-printer"

// Include the auto-generated portion of the assembly writer.
#include "TriCoreGenAsmWriter.inc"

void TriCoreInstPrinter::printInst(const MCInst *MI, uint64_t Address,
                                   StringRef Annot, const MCSubtargetInfo &STI,
                                   raw_ostream &O) {
  printInstruction(MI, Address, STI, O);
  printAnnotation(O, Annot);
}

void TriCoreInstPrinter::printRegName(raw_ostream &O, unsigned RegNo) const {
#ifndef NDEBUG
  if (RegNo == TriCore::PSW_C)
    llvm_unreachable("Pseudo-register should never be emitted");
#endif

  O << "%" << getRegisterName(RegNo);
}

void TriCoreInstPrinter::printOperand(const MCInst *MI, unsigned OpNo,
                                      const MCSubtargetInfo &STI,
                                      raw_ostream &O, const char *Modifier) {
  assert((Modifier == 0 || Modifier[0] == 0) && "No modifiers supported");
  const MCOperand &MO = MI->getOperand(OpNo);

  if (MO.isReg()) {
    printRegName(O, MO.getReg());
    return;
  }

  if (MO.isImm()) {
    O << MO.getImm();
    return;
  }

  assert(MO.isExpr() && "Unknown operand kind in printOperand");
  MO.getExpr()->print(O, &MAI);
}

void TriCoreInstPrinter::printSystemRegister(const MCInst *MI,
                                             unsigned int OpNo,
                                             const MCSubtargetInfo &STI,
                                             raw_ostream &O) {
  const unsigned Imm = MI->getOperand(OpNo).getImm();
  const auto *SysReg = TriCoreSysReg::lookupSysRegByEncoding(Imm);
  if (SysReg && SysReg->haveFeatures(STI.getFeatureBits()))
    O << '$' << SysReg->Name;
  else
    O << Imm;
}
