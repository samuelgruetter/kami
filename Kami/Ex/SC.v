Require Import Ascii Bool String List.
Require Import Lib.CommonTactics Lib.Indexer Lib.ilist Lib.Word Lib.Struct.
Require Import Kami.Syntax Kami.Notations.
Require Import Kami.Semantics Kami.Specialize Kami.Duplicate.
Require Import Kami.Wf Kami.Tactics.
Require Import Ex.MemTypes.

Set Implicit Arguments.

(* The SC module is defined as follows: SC = n * Pinst + Minst,
 * where Pinst denotes an instantaneous processor core
 * and Minst denotes an instantaneous memory.
 *)

(* Abstract ISA *)
Section DecExec.
  Variables opIdx addrSize iaddrSize instBytes dataBytes rfIdx: nat.

  Definition Pc := Bit (2 + iaddrSize).
  
  (* opcode-related *)
  Definition OpcodeK := SyntaxKind (Bit opIdx).
  Definition OpcodeE (ty: Kind -> Type) := Expr ty OpcodeK.
  Definition OpcodeT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> OpcodeE ty.

  Definition opLd := WO~0~0.
  Definition opSt := WO~0~1.
  Definition opNm := WO~1~1.
  
  Definition OptypeK := SyntaxKind (Bit 2).
  Definition OptypeE (ty: Kind -> Type) := Expr ty OptypeK.
  Definition OptypeT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> OptypeE ty.
  
  (* load-related *)
  Definition LdDstK := SyntaxKind (Bit rfIdx).
  Definition LdDstE (ty: Kind -> Type) := Expr ty LdDstK.
  Definition LdDstT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> LdDstE ty.

  Definition LdAddrK := SyntaxKind (Bit addrSize).
  Definition LdAddrE (ty: Kind -> Type) := Expr ty LdAddrK.
  Definition LdAddrT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> LdAddrE ty.

  Definition LdSrcK := SyntaxKind (Bit rfIdx).
  Definition LdSrcE (ty: Kind -> Type) := Expr ty LdSrcK.
  Definition LdSrcT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> LdSrcE ty.

  Definition LdAddrCalcT :=
    forall ty,
      fullType ty (SyntaxKind (Bit addrSize)) -> (* base address *)
      fullType ty (SyntaxKind (Data dataBytes)) -> (* dst value *)
      Expr ty (SyntaxKind (Bit addrSize)).
  
  (* store-related *)
  Definition StAddrK := SyntaxKind (Bit addrSize).
  Definition StAddrE (ty: Kind -> Type) := Expr ty StAddrK.
  Definition StAddrT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> StAddrE ty.
  
  Definition StSrcK := SyntaxKind (Bit rfIdx).
  Definition StSrcE (ty: Kind -> Type) := Expr ty StSrcK.
  Definition StSrcT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> StSrcE ty.

  Definition StAddrCalcT :=
    forall ty,
      fullType ty (SyntaxKind (Bit addrSize)) -> (* base address *)
      fullType ty (SyntaxKind (Data dataBytes)) -> (* dst value *)
      Expr ty (SyntaxKind (Bit addrSize)).

  Definition StVSrcK := SyntaxKind (Bit rfIdx).
  Definition StVSrcE (ty: Kind -> Type) := Expr ty StVSrcK.
  Definition StVSrcT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> StVSrcE ty.

  (* general sources *)
  Definition Src1K := SyntaxKind (Bit rfIdx).
  Definition Src1E (ty: Kind -> Type) := Expr ty Src1K.
  Definition Src1T := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> Src1E ty.

  Definition Src2K := SyntaxKind (Bit rfIdx).
  Definition Src2E (ty: Kind -> Type) := Expr ty Src2K.
  Definition Src2T := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> Src2E ty.

  (* general destination *)
  Definition DstK := SyntaxKind (Bit rfIdx).
  Definition DstE (ty: Kind -> Type) := Expr ty DstK.
  Definition DstT := forall ty, fullType ty (SyntaxKind (Data instBytes)) -> DstE ty.
  
  (* execution *)
  Definition StateK := SyntaxKind (Vector (Data dataBytes) rfIdx).
  Definition StateT (ty : Kind -> Type) := fullType ty StateK.
  Definition StateE (ty : Kind -> Type) := Expr ty StateK.

  Definition ExecT := forall ty, fullType ty (SyntaxKind (Data dataBytes)) -> (* val1 *)
                                 fullType ty (SyntaxKind (Data dataBytes)) -> (* val2 *)
                                 fullType ty (SyntaxKind Pc) -> (* pc *)
                                 fullType ty (SyntaxKind (Data instBytes)) -> (* rawInst *)
                                 Expr ty (SyntaxKind (Data dataBytes)). (* executed value *)
  Definition NextPcT := forall ty, StateT ty -> (* rf *)
                                   fullType ty (SyntaxKind Pc) -> (* pc *)
                                   fullType ty (SyntaxKind (Data instBytes)) -> (* rawInst *)
                                   Expr ty (SyntaxKind Pc). (* next pc *)
  Definition AlignAddrT := forall ty, fullType ty (SyntaxKind (Bit addrSize)) -> (* addr *)
                                      Expr ty (SyntaxKind (Bit addrSize)). (* aligned addr *)
  
End DecExec.

Hint Unfold Pc OpcodeK OpcodeE OpcodeT OptypeK OptypeE OptypeT opLd opSt opNm
     LdDstK LdDstE LdDstT LdAddrK LdAddrE LdAddrT LdSrcK LdSrcE LdSrcT
     StAddrK StAddrE StAddrT StSrcK StSrcE StSrcT StVSrcK StVSrcE StVSrcT
     Src1K Src1E Src1T Src2K Src2E Src2T
     StateK StateE StateT ExecT NextPcT AlignAddrT : MethDefs.

(* The module definition for Minst with n ports *)
Section MemInst.
  Variable n : nat.
  Variable addrSize : nat.
  Variable dataBytes : nat.

  Definition RqFromProc := RqFromProc dataBytes (Bit addrSize).
  Definition RsToProc := RsToProc dataBytes.

  Definition memInst :=
    MODULE {
      Register "mem" : Vector (Data dataBytes) addrSize <- Default

      with Method "memOp" (a : Struct RqFromProc) : Struct RsToProc :=
        If !#a!RqFromProc@."op" then (* load *)
          Read memv <- "mem";
          LET ldval <- #memv@[#a!RqFromProc@."addr"];
          Ret (STRUCT { "data" ::= #ldval } :: Struct RsToProc)
        else (* store *)
          Read memv <- "mem";
          Write "mem" <- #memv@[ #a!RqFromProc@."addr" <- #a!RqFromProc@."data" ];
          Ret (STRUCT { "data" ::= $$Default } :: Struct RsToProc)
        as na;
        Ret #na
    }.
    
  Definition memOp := MethodSig "memOp"(Struct RqFromProc) : Struct RsToProc.
  
End MemInst.

Hint Unfold RqFromProc RsToProc memOp : MethDefs.
Hint Unfold memInst : ModuleDefs.

Section MMIO.
  Variable addrSize: nat.
  Variable dataBytes: nat.

  Definition IsMMIOE (ty: Kind -> Type) := Expr ty (SyntaxKind Bool).
  Definition IsMMIOT :=
    forall ty, fullType ty (SyntaxKind (Bit addrSize)) -> IsMMIOE ty.

  Variable (isMMIO: IsMMIOT).

  Local Notation RqFromProc := (RqFromProc addrSize dataBytes).
  Local Notation RsToProc := (RsToProc dataBytes).

  Definition mmioExec :=
    MethodSig "mmioExec"(Struct RqFromProc): Struct RsToProc.

  Definition mm := MODULE {
    Register "mem" : Vector (Data dataBytes) addrSize <- Default

    with Method "memOp" (a : Struct RqFromProc): Struct RsToProc :=
      LET addr <- #a!RqFromProc@."addr";

      If (isMMIO _ addr) then (** mmio *)
        Call rs <- mmioExec(#a);
        Ret #rs
      else
        If !#a!RqFromProc@."op" then (** load *)
          Read memv <- "mem";
          LET ldval <- #memv@[#a!RqFromProc@."addr"];
          Ret (STRUCT { "data" ::= #ldval } :: Struct RsToProc)
        else (** store *)
          Read memv <- "mem";
          Write "mem" <- #memv@[ #a!RqFromProc@."addr" <- #a!RqFromProc@."data" ];
          Ret (STRUCT { "data" ::= $$Default } :: Struct RsToProc)
        as na;
        Ret #na
      as na;
      Ret #na
  }.
    
End MMIO.

Hint Unfold IsMMIOE IsMMIOT mmioExec : MethDefs.
Hint Unfold mm : ModuleDefs.

(* The module definition for Pinst *)
Section ProcInst.
  Variables addrSize iaddrSize instBytes dataBytes rfIdx : nat.

  (* External abstract ISA: decoding and execution *)
  Variables (getOptype: OptypeT instBytes)
            (getLdDst: LdDstT instBytes rfIdx)
            (getLdAddr: LdAddrT addrSize instBytes)
            (getLdSrc: LdSrcT instBytes rfIdx)
            (calcLdAddr: LdAddrCalcT addrSize dataBytes)
            (getStAddr: StAddrT addrSize instBytes)
            (getStSrc: StSrcT instBytes rfIdx)
            (calcStAddr: StAddrCalcT addrSize dataBytes)
            (getStVSrc: StVSrcT instBytes rfIdx)
            (getSrc1: Src1T instBytes rfIdx)
            (getSrc2: Src2T instBytes rfIdx)
            (getDst: DstT instBytes rfIdx)
            (exec: ExecT iaddrSize instBytes dataBytes)
            (getNextPc: NextPcT iaddrSize instBytes dataBytes rfIdx)
            (alignAddr: AlignAddrT addrSize).

  Definition nextPc {ty} ppc st rawInst :=
    (Write "pc" <- getNextPc ty st ppc rawInst;
     Retv)%kami_action.

  Record ProcInit := { pcInit : ConstT (Pc iaddrSize);
                       rfInit : ConstT (Vector (Data dataBytes) rfIdx)
                     }.
  Definition procInitDefault :=
    {| pcInit := Default; rfInit := Default |}.

  Local Notation memOp := (memOp addrSize dataBytes).

  Definition pgmInit :=
    MethodSig "pgmInit"(): Data instBytes.
  
  Variables (procInit: ProcInit).

  Definition procInst := MODULE {
    Register "pc" : Pc iaddrSize <- (pcInit procInit)
    with Register "rf" : Vector (Data dataBytes) rfIdx <- (rfInit procInit)

    with Register "pinit" : Bool <- Default
    with Register "pinitOfs" : Bit iaddrSize <- Default
    with Register "pgm" : Vector (Data instBytes) iaddrSize <- Default

    (** Phase 1: initialize the program [pinit == false] *)

    with Rule "pgmInit" :=
      Read pinit : Bool <- "pinit";
      Read pinitOfs : Bit iaddrSize <- "pinitOfs";
      Read pgm : Vector (Data instBytes) iaddrSize <- "pgm";
      Assert !#pinit;
      Assert ((UniBit (Inv _) #pinitOfs) != $0);
      Call irs <- pgmInit ();
      Write "pgm" <- #pgm@[#pinitOfs <- #irs];
      Write "pinitOfs" <- #pinitOfs + $1;
      Retv

    with Rule "pgmInitEnd" :=
      Read pinit : Bool <- "pinit";
      Read pinitOfs : Bit iaddrSize <- "pinitOfs";
      Read pgm : Vector (Data instBytes) iaddrSize <- "pgm";
      Assert !#pinit;
      Assert ((UniBit (Inv _) #pinitOfs) == $0);
      Call irs <- pgmInit ();
      Write "pgm" <- #pgm@[#pinitOfs <- #irs];
      Write "pinit" <- !#pinit;
      Retv

    (** Phase 2: execute the program [pinit == true] *)
        
    with Rule "execLd" :=
      Read ppc : Pc iaddrSize <- "pc";
      Read rf : Vector (Data dataBytes) rfIdx <- "rf";
      Read pinit : Bool <- "pinit";
      Read pgm : Vector (Data instBytes) iaddrSize <- "pgm";
      Assert #pinit;
      LET rawInst <- #pgm@[_truncLsb_ #ppc];
      Assert (getOptype _ rawInst == $$opLd);
      LET dstIdx <- getLdDst _ rawInst;
      Assert (#dstIdx != $0);
      LET addr <- getLdAddr _ rawInst;
      LET srcIdx <- getLdSrc _ rawInst;
      LET srcVal <- #rf@[#srcIdx];
      LET laddr <- calcLdAddr _ addr srcVal;
      Call ldRep <- memOp(STRUCT { "addr" ::= alignAddr _ laddr;
                                   "op" ::= $$false;
                                   "data" ::= $$Default });
      Write "rf" <- #rf@[#dstIdx <- #ldRep!(RsToProc dataBytes)@."data"];
      nextPc ppc rf rawInst
             
    with Rule "execLdZ" :=
      Read ppc : Pc iaddrSize <- "pc";
      Read rf : Vector (Data dataBytes) rfIdx <- "rf";
      Read pinit : Bool <- "pinit";
      Read pgm : Vector (Data instBytes) iaddrSize <- "pgm";
      Assert #pinit;
      LET rawInst <- #pgm@[_truncLsb_ #ppc];
      Assert (getOptype _ rawInst == $$opLd);
      LET regIdx <- getLdDst _ rawInst;
      Assert (#regIdx == $0);
      nextPc ppc rf rawInst

    with Rule "execSt" :=
      Read ppc : Pc iaddrSize <- "pc";
      Read rf : Vector (Data dataBytes) rfIdx <- "rf";
      Read pinit : Bool <- "pinit";
      Read pgm : Vector (Data instBytes) iaddrSize <- "pgm";
      Assert #pinit;
      LET rawInst <- #pgm@[_truncLsb_ #ppc];
      Assert (getOptype _ rawInst == $$opSt);
      LET addr <- getStAddr _ rawInst;
      LET srcIdx <- getStSrc _ rawInst;
      LET srcVal <- #rf@[#srcIdx];
      LET vsrcIdx <- getStVSrc _ rawInst;
      LET stVal <- #rf@[#vsrcIdx];
      LET saddr <- calcStAddr _ addr srcVal;
      Call memOp(STRUCT { "addr" ::= alignAddr _ saddr;
                          "op" ::= $$true;
                          "data" ::= #stVal });
      nextPc ppc rf rawInst

    with Rule "execNm" :=
      Read ppc : Pc iaddrSize <- "pc";
      Read rf : Vector (Data dataBytes) rfIdx <- "rf";
      Read pinit : Bool <- "pinit";
      Read pgm : Vector (Data instBytes) iaddrSize <- "pgm";
      Assert #pinit;
      LET rawInst <- #pgm@[_truncLsb_ #ppc];
      Assert (getOptype _ rawInst == $$opNm);
      LET src1 <- getSrc1 _ rawInst;
      LET val1 <- #rf@[#src1];
      LET src2 <- getSrc2 _ rawInst;
      LET val2 <- #rf@[#src2];
      LET dst <- getDst _ rawInst;
      Assert (#dst != $0);
      LET execVal <- exec _ val1 val2 ppc rawInst;
      Write "rf" <- #rf@[#dst <- #execVal];
      nextPc ppc rf rawInst

    with Rule "execNmZ" :=
      Read ppc : Pc iaddrSize <- "pc";
      Read rf : Vector (Data dataBytes) rfIdx <- "rf";
      Read pinit : Bool <- "pinit";
      Read pgm : Vector (Data instBytes) iaddrSize <- "pgm";
      Assert #pinit;
      LET rawInst <- #pgm@[_truncLsb_ #ppc];
      Assert (getOptype _ rawInst == $$opNm);
      LET dst <- getDst _ rawInst;
      Assert (#dst == $0);
      nextPc ppc rf rawInst
  }.

End ProcInst.

Hint Unfold nextPc procInitDefault pgmInit : MethDefs.
Hint Unfold procInst : ModuleDefs.

Section SC.
  Variables addrSize iaddrSize instBytes dataBytes rfIdx : nat.

  (* External abstract ISA: decoding and execution *)
  Variables (getOptype: OptypeT instBytes)
            (getLdDst: LdDstT instBytes rfIdx)
            (getLdAddr: LdAddrT addrSize instBytes)
            (getLdSrc: LdSrcT instBytes rfIdx)
            (calcLdAddr: LdAddrCalcT addrSize dataBytes)
            (getStAddr: StAddrT addrSize instBytes)
            (getStSrc: StSrcT instBytes rfIdx)
            (calcStAddr: StAddrCalcT addrSize dataBytes)
            (getStVSrc: StVSrcT instBytes rfIdx)
            (getSrc1: Src1T instBytes rfIdx)
            (getSrc2: Src2T instBytes rfIdx)
            (getDst: DstT instBytes rfIdx)
            (exec: ExecT iaddrSize instBytes dataBytes)
            (getNextPc: NextPcT iaddrSize instBytes dataBytes rfIdx)
            (alignAddr: AlignAddrT addrSize)
            (isMMIO: IsMMIOT addrSize).

  Variable n: nat.

  Definition pinst := procInst getOptype getLdDst getLdAddr getLdSrc calcLdAddr
                               getStAddr getStSrc calcStAddr getStVSrc
                               getSrc1 getSrc2 getDst exec getNextPc alignAddr.

  Variables (procInit: ProcInit iaddrSize dataBytes rfIdx).

  (** Just for singlecore (for now) *)
  Definition scmm := ConcatMod (pinst procInit) (mm dataBytes isMMIO).

End SC.

Hint Unfold pinst scmm : ModuleDefs.

Section Facts.
  Variables addrSize iaddrSize instBytes dataBytes rfIdx : nat.

  (* External abstract ISA: decoding and execution *)
  Variables (getOptype: OptypeT instBytes)
            (getLdDst: LdDstT instBytes rfIdx)
            (getLdAddr: LdAddrT addrSize instBytes)
            (getLdSrc: LdSrcT instBytes rfIdx)
            (calcLdAddr: LdAddrCalcT addrSize dataBytes)
            (getStAddr: StAddrT addrSize instBytes)
            (getStSrc: StSrcT instBytes rfIdx)
            (calcStAddr: StAddrCalcT addrSize dataBytes)
            (getStVSrc: StVSrcT instBytes rfIdx)
            (getSrc1: Src1T instBytes rfIdx)
            (getSrc2: Src2T instBytes rfIdx)
            (getDst: DstT instBytes rfIdx)
            (exec: ExecT iaddrSize instBytes dataBytes)
            (getNextPc: NextPcT iaddrSize instBytes dataBytes rfIdx)
            (alignAddr: AlignAddrT addrSize)
            (isMMIO: IsMMIOT addrSize).

  Lemma pinst_ModEquiv:
    forall init,
      ModPhoasWf (pinst getOptype getLdDst getLdAddr getLdSrc calcLdAddr
                        getStAddr getStSrc calcStAddr getStVSrc
                        getSrc1 getSrc2 getDst exec getNextPc alignAddr init).
  Proof.
    kequiv.
  Qed.
  Hint Resolve pinst_ModEquiv.

  Lemma memInst_ModEquiv:
    ModPhoasWf (memInst addrSize dataBytes).
  Proof.
    kequiv.
  Qed.
  Hint Resolve memInst_ModEquiv.

  Lemma mm_ModEquiv: ModPhoasWf (mm addrSize isMMIO).
  Proof.
    kequiv.
  Qed.
  Hint Resolve mm_ModEquiv.
  
  Lemma scmm_ModEquiv:
    forall inits,
      ModPhoasWf (scmm getOptype getLdDst getLdAddr getLdSrc calcLdAddr
                       getStAddr getStSrc calcStAddr getStVSrc
                       getSrc1 getSrc2 getDst exec getNextPc alignAddr
                       isMMIO inits).
  Proof.
    kequiv.
  Qed.
  
End Facts.

Hint Resolve pinst_ModEquiv memInst_ModEquiv mm_ModEquiv scmm_ModEquiv.

