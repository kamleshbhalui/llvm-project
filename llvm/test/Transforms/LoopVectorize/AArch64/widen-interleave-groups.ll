; RUN: opt -p loop-vectorize -force-vector-width=4 -force-vector-interleave=1 -S %s | FileCheck %s --check-prefix=VF4
; RUN: opt -p loop-vectorize -force-vector-width=16 -force-vector-interleave=1 -S %s | FileCheck %s --check-prefix=CAST

target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx"

define void @load_store_factor_mismatch(ptr noalias %src, ptr noalias %dst, ptr noalias %side) {
; VF4-LABEL: define void @load_store_factor_mismatch(
; VF4:       vector.body:
; VF4:         [[SRC:%.*]] = getelementptr inbounds i64, ptr %src
; VF4-NEXT:    [[LOAD3:%.*]] = load <12 x i64>, ptr [[SRC]], align 8
; VF4-NEXT:    [[FIELD0:%.*]] = shufflevector <12 x i64> [[LOAD3]], <12 x i64> poison, <4 x i32> <i32 0, i32 3, i32 6, i32 9>
; VF4-NEXT:    [[FIELD1:%.*]] = shufflevector <12 x i64> [[LOAD3]], <12 x i64> poison, <4 x i32> <i32 1, i32 4, i32 7, i32 10>
; VF4-NEXT:    [[FIELD2:%.*]] = shufflevector <12 x i64> [[LOAD3]], <12 x i64> poison, <4 x i32> <i32 2, i32 5, i32 8, i32 11>
; VF4:         [[PACK:%.*]] = shufflevector <4 x i64> [[FIELD0]], <4 x i64> [[FIELD1]], <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
; VF4-NEXT:    [[INTERLEAVED:%.*]] = shufflevector <8 x i64> [[PACK]], <8 x i64> poison, <8 x i32> <i32 0, i32 4, i32 1, i32 5, i32 2, i32 6, i32 3, i32 7>
; VF4-NEXT:    store <8 x i64> [[INTERLEAVED]]
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %src.base = mul nuw nsw i64 %iv, 3
  %src.p0 = getelementptr inbounds i64, ptr %src, i64 %src.base
  %l0 = load i64, ptr %src.p0, align 8
  %src.p1 = getelementptr inbounds i64, ptr %src.p0, i64 1
  %l1 = load i64, ptr %src.p1, align 8
  %src.p2 = getelementptr inbounds i64, ptr %src.p0, i64 2
  %l2 = load i64, ptr %src.p2, align 8
  %dst.base = shl nuw nsw i64 %iv, 1
  %dst.p0 = getelementptr inbounds i64, ptr %dst, i64 %dst.base
  store i64 %l0, ptr %dst.p0, align 8
  %dst.p1 = getelementptr inbounds i64, ptr %dst.p0, i64 1
  store i64 %l1, ptr %dst.p1, align 8
  %side.p = getelementptr inbounds i64, ptr %side, i64 %iv
  store i64 %l2, ptr %side.p, align 8
  %iv.next = add nuw nsw i64 %iv, 1
  %ec = icmp eq i64 %iv.next, 100
  br i1 %ec, label %exit, label %loop

exit:
  ret void
}


define void @uniform_cast_operand_must_splat_to_widened_vf(i32 %c0, i32 %c1, i32 %n, ptr noalias %r1, ptr noalias %r2, ptr noalias %out) {
; CAST-LABEL: define void @uniform_cast_operand_must_splat_to_widened_vf(
; CAST:       vector.ph:
; CAST:         [[BC1_INS:%.*]] = insertelement <16 x i32> poison, i32 %c1
; CAST-NEXT:    [[BC1:%.*]] = shufflevector <16 x i32> [[BC1_INS]]
; CAST-NEXT:    [[BC0_INS:%.*]] = insertelement <16 x i32> poison, i32 %c0
; CAST-NEXT:    [[BC0:%.*]] = shufflevector <16 x i32> [[BC0_INS]]
; CAST:         [[TC0:%.*]] = trunc <16 x i32> [[BC0]] to <16 x i16>
; CAST:         [[TC1:%.*]] = trunc <16 x i32> [[BC1]] to <16 x i16>
; CAST:       vector.body:
; CAST:         [[WIDE_LOAD0:%.*]] = load <64 x i8>
; CAST:         [[ZEXT0:%.*]] = zext <64 x i8> [[WIDE_LOAD0]] to <64 x i16>
; CAST:         [[C0:%.*]] = extractelement <16 x i16> [[TC0]], i64 0
; CAST:         [[C0_SPLAT_INSERT:%.*]] = insertelement <64 x i16> poison, i16 [[C0]], i64 0
; CAST:         [[C0_SPLAT:%.*]] = shufflevector <64 x i16> [[C0_SPLAT_INSERT]], <64 x i16> poison, <64 x i32> zeroinitializer
; CAST:         mul <64 x i16> [[C0_SPLAT]], [[ZEXT0]]
entry:
  %cmp0 = icmp sgt i32 %n, 0
  br i1 %cmp0, label %loop, label %exit

loop:
  %iv = phi i32 [ 0, %entry ], [ %iv.next, %loop ]
  %iv.ext = zext i32 %iv to i64
  %off = shl nuw nsw i64 %iv.ext, 2
  %r1.base = getelementptr inbounds nuw i8, ptr %r1, i64 %off
  %r2.base = getelementptr inbounds nuw i8, ptr %r2, i64 %off
  %out.base = getelementptr inbounds nuw i8, ptr %out, i64 %off

  %r1.0 = load i8, ptr %r1.base, align 1
  %r1.0.ext = zext i8 %r1.0 to i32
  %mul.0 = mul nsw i32 %c0, %r1.0.ext
  %r2.0 = load i8, ptr %r2.base, align 1
  %r2.0.ext = zext i8 %r2.0 to i32
  %mul2.0 = mul nsw i32 %c1, %r2.0.ext
  %add.0 = add nsw i32 %mul2.0, %mul.0
  %shr.0 = lshr i32 %add.0, 8
  %tr.0 = trunc i32 %shr.0 to i8
  store i8 %tr.0, ptr %out.base, align 1

  %r1.p1 = getelementptr inbounds nuw i8, ptr %r1.base, i64 1
  %r1.1 = load i8, ptr %r1.p1, align 1
  %r1.1.ext = zext i8 %r1.1 to i32
  %mul.1 = mul nsw i32 %c0, %r1.1.ext
  %r2.p1 = getelementptr inbounds nuw i8, ptr %r2.base, i64 1
  %r2.1 = load i8, ptr %r2.p1, align 1
  %r2.1.ext = zext i8 %r2.1 to i32
  %mul2.1 = mul nsw i32 %c1, %r2.1.ext
  %add.1 = add nsw i32 %mul2.1, %mul.1
  %shr.1 = lshr i32 %add.1, 8
  %tr.1 = trunc i32 %shr.1 to i8
  %out.p1 = getelementptr inbounds nuw i8, ptr %out.base, i64 1
  store i8 %tr.1, ptr %out.p1, align 1

  %r1.p2 = getelementptr inbounds nuw i8, ptr %r1.base, i64 2
  %r1.2 = load i8, ptr %r1.p2, align 1
  %r1.2.ext = zext i8 %r1.2 to i32
  %mul.2 = mul nsw i32 %c0, %r1.2.ext
  %r2.p2 = getelementptr inbounds nuw i8, ptr %r2.base, i64 2
  %r2.2 = load i8, ptr %r2.p2, align 1
  %r2.2.ext = zext i8 %r2.2 to i32
  %mul2.2 = mul nsw i32 %c1, %r2.2.ext
  %add.2 = add nsw i32 %mul2.2, %mul.2
  %shr.2 = lshr i32 %add.2, 8
  %tr.2 = trunc i32 %shr.2 to i8
  %out.p2 = getelementptr inbounds nuw i8, ptr %out.base, i64 2
  store i8 %tr.2, ptr %out.p2, align 1

  %r1.p3 = getelementptr inbounds nuw i8, ptr %r1.base, i64 3
  %r1.3 = load i8, ptr %r1.p3, align 1
  %r1.3.ext = zext i8 %r1.3 to i32
  %mul.3 = mul nsw i32 %c0, %r1.3.ext
  %r2.p3 = getelementptr inbounds nuw i8, ptr %r2.base, i64 3
  %r2.3 = load i8, ptr %r2.p3, align 1
  %r2.3.ext = zext i8 %r2.3 to i32
  %mul2.3 = mul nsw i32 %c1, %r2.3.ext
  %add.3 = add nsw i32 %mul2.3, %mul.3
  %shr.3 = lshr i32 %add.3, 8
  %tr.3 = trunc i32 %shr.3 to i8
  %out.p3 = getelementptr inbounds nuw i8, ptr %out.base, i64 3
  store i8 %tr.3, ptr %out.p3, align 1

  %iv.next = add nuw nsw i32 %iv, 1
  %done = icmp eq i32 %iv.next, %n
  br i1 %done, label %exit, label %loop

exit:
  ret void
}

define void @mixed_alignment_uses_group_alignment(ptr noalias %src, ptr noalias %dst) {
; VF4-LABEL: define void @mixed_alignment_uses_group_alignment(
; VF4:       vector.body:
; VF4:         [[LOAD:%.*]] = load <8 x i64>, ptr {{%.*}}, align 4
; VF4:         store <8 x i64> [[LOAD]], ptr {{%.*}}, align 4
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %base = shl nuw nsw i64 %iv, 1
  %src.0 = getelementptr inbounds i64, ptr %src, i64 %base
  %l0 = load i64, ptr %src.0, align 8
  %src.1 = getelementptr inbounds i64, ptr %src.0, i64 1
  %l1 = load i64, ptr %src.1, align 4
  %dst.0 = getelementptr inbounds i64, ptr %dst, i64 %base
  store i64 %l0, ptr %dst.0, align 8
  %dst.1 = getelementptr inbounds i64, ptr %dst.0, i64 1
  store i64 %l1, ptr %dst.1, align 4
  %iv.next = add nuw nsw i64 %iv, 1
  %done = icmp eq i64 %iv.next, 100
  br i1 %done, label %exit, label %loop

exit:
  ret void
}

define void @reverse_interleave_not_widened(ptr noalias %src, ptr noalias %dst) {
; VF4-LABEL: define void @reverse_interleave_not_widened(
; VF4:       vector.body:
; VF4:         load <8 x i64>
; VF4:         shufflevector <8 x i64>
; VF4:         store <8 x i64>
entry:
  br label %loop

loop:
  %iv = phi i64 [ 200, %entry ], [ %iv.next, %loop ]
  %src.0 = getelementptr inbounds i64, ptr %src, i64 %iv
  %l0 = load i64, ptr %src.0, align 8
  %src.1 = getelementptr inbounds i64, ptr %src.0, i64 -1
  %l1 = load i64, ptr %src.1, align 8
  %dst.0 = getelementptr inbounds i64, ptr %dst, i64 %iv
  store i64 %l0, ptr %dst.0, align 8
  %dst.1 = getelementptr inbounds i64, ptr %dst.0, i64 -1
  store i64 %l1, ptr %dst.1, align 8
  %iv.next = add nsw i64 %iv, -2
  %done = icmp eq i64 %iv.next, 0
  br i1 %done, label %exit, label %loop

exit:
  ret void
}


define void @direct_load_members_must_share_load_group(ptr noalias %src.a, ptr noalias %src.b, ptr noalias %dst, ptr noalias %side) {
; VF4-LABEL: define void @direct_load_members_must_share_load_group(
; VF4:       vector.body:
; VF4:         [[A_WIDE:%.*]] = load <8 x i64>, ptr {{%.*}}, align 8
; VF4:         [[A0:%.*]] = shufflevector <8 x i64> [[A_WIDE]], <8 x i64> poison, <4 x i32> <i32 0, i32 2, i32 4, i32 6>
; VF4:         [[A1:%.*]] = shufflevector <8 x i64> [[A_WIDE]], <8 x i64> poison, <4 x i32> <i32 1, i32 3, i32 5, i32 7>
; VF4:         [[B_WIDE:%.*]] = load <8 x i64>, ptr {{%.*}}, align 8
; VF4:         [[B0:%.*]] = shufflevector <8 x i64> [[B_WIDE]], <8 x i64> poison, <4 x i32> <i32 0, i32 2, i32 4, i32 6>
; VF4:         [[B1:%.*]] = shufflevector <8 x i64> [[B_WIDE]], <8 x i64> poison, <4 x i32> <i32 1, i32 3, i32 5, i32 7>
; VF4:         [[DST_PACK:%.*]] = shufflevector <4 x i64> [[A0]], <4 x i64> [[B1]], <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
; VF4:         [[DST_INTERLEAVED:%.*]] = shufflevector <8 x i64> [[DST_PACK]], <8 x i64> poison, <8 x i32> <i32 0, i32 4, i32 1, i32 5, i32 2, i32 6, i32 3, i32 7>
; VF4:         store <8 x i64> [[DST_INTERLEAVED]], ptr {{%.*}}, align 8
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %base = shl nuw nsw i64 %iv, 1
  %a.p0 = getelementptr inbounds i64, ptr %src.a, i64 %base
  %a0 = load i64, ptr %a.p0, align 8
  %a.p1 = getelementptr inbounds i64, ptr %a.p0, i64 1
  %a1 = load i64, ptr %a.p1, align 8
  %b.p0 = getelementptr inbounds i64, ptr %src.b, i64 %base
  %b0 = load i64, ptr %b.p0, align 8
  %b.p1 = getelementptr inbounds i64, ptr %b.p0, i64 1
  %b1 = load i64, ptr %b.p1, align 8
  %dst.p0 = getelementptr inbounds i64, ptr %dst, i64 %base
  store i64 %a0, ptr %dst.p0, align 8
  %dst.p1 = getelementptr inbounds i64, ptr %dst.p0, i64 1
  store i64 %b1, ptr %dst.p1, align 8
  %side.p0 = getelementptr inbounds i64, ptr %side, i64 %base
  store i64 %a1, ptr %side.p0, align 8
  %side.p1 = getelementptr inbounds i64, ptr %side.p0, i64 1
  store i64 %b0, ptr %side.p1, align 8
  %iv.next = add nuw nsw i64 %iv, 1
  %done = icmp eq i64 %iv.next, 100
  br i1 %done, label %exit, label %loop

exit:
  ret void
}


define void @op_load_members_must_share_load_group(ptr noalias %src.a, ptr noalias %src.b, ptr noalias %dst, ptr noalias %side) {
; VF4-LABEL: define void @op_load_members_must_share_load_group(
; VF4:       vector.body:
; VF4:         [[A_WIDE:%.*]] = load <8 x i64>, ptr {{%.*}}, align 8
; VF4:         [[A0:%.*]] = shufflevector <8 x i64> [[A_WIDE]], <8 x i64> poison, <4 x i32> <i32 0, i32 2, i32 4, i32 6>
; VF4:         [[A1:%.*]] = shufflevector <8 x i64> [[A_WIDE]], <8 x i64> poison, <4 x i32> <i32 1, i32 3, i32 5, i32 7>
; VF4:         [[B_WIDE:%.*]] = load <8 x i64>, ptr {{%.*}}, align 8
; VF4:         [[B0:%.*]] = shufflevector <8 x i64> [[B_WIDE]], <8 x i64> poison, <4 x i32> <i32 0, i32 2, i32 4, i32 6>
; VF4:         [[B1:%.*]] = shufflevector <8 x i64> [[B_WIDE]], <8 x i64> poison, <4 x i32> <i32 1, i32 3, i32 5, i32 7>
; VF4:         [[A0_ADD:%.*]] = add nsw <4 x i64> [[A0]],
; VF4:         [[B1_ADD:%.*]] = add nsw <4 x i64> [[B1]],
; VF4:         [[DST_PACK:%.*]] = shufflevector <4 x i64> [[A0_ADD]], <4 x i64> [[B1_ADD]], <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
; VF4:         [[DST_INTERLEAVED:%.*]] = shufflevector <8 x i64> [[DST_PACK]], <8 x i64> poison, <8 x i32> <i32 0, i32 4, i32 1, i32 5, i32 2, i32 6, i32 3, i32 7>
; VF4:         store <8 x i64> [[DST_INTERLEAVED]], ptr {{%.*}}, align 8
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %base = shl nuw nsw i64 %iv, 1
  %a.p0 = getelementptr inbounds i64, ptr %src.a, i64 %base
  %a0 = load i64, ptr %a.p0, align 8
  %a.p1 = getelementptr inbounds i64, ptr %a.p0, i64 1
  %a1 = load i64, ptr %a.p1, align 8
  %b.p0 = getelementptr inbounds i64, ptr %src.b, i64 %base
  %b0 = load i64, ptr %b.p0, align 8
  %b.p1 = getelementptr inbounds i64, ptr %b.p0, i64 1
  %b1 = load i64, ptr %b.p1, align 8
  %a0.add = add nsw i64 %a0, 1
  %b1.add = add nsw i64 %b1, 1
  %dst.p0 = getelementptr inbounds i64, ptr %dst, i64 %base
  store i64 %a0.add, ptr %dst.p0, align 8
  %dst.p1 = getelementptr inbounds i64, ptr %dst.p0, i64 1
  store i64 %b1.add, ptr %dst.p1, align 8
  %side.p0 = getelementptr inbounds i64, ptr %side, i64 %base
  store i64 %a1, ptr %side.p0, align 8
  %side.p1 = getelementptr inbounds i64, ptr %side.p0, i64 1
  store i64 %b0, ptr %side.p1, align 8
  %iv.next = add nuw nsw i64 %iv, 1
  %done = icmp eq i64 %iv.next, 100
  br i1 %done, label %exit, label %loop

exit:
  ret void
}


define void @uniform_store_root_must_splat_to_widened_vf(ptr noalias %dst, i32 %a) {
; VF4-LABEL: define void @uniform_store_root_must_splat_to_widened_vf(
; VF4:       vector.body:
; VF4:         [[SPLAT_INS:%.*]] = insertelement <8 x i32> poison, i32 {{%.*}}, i64 0
; VF4-NEXT:    [[SPLAT:%.*]] = shufflevector <8 x i32> [[SPLAT_INS]], <8 x i32> poison, <8 x i32> zeroinitializer
; VF4-NEXT:    store <8 x i32> [[SPLAT]], ptr {{%.*}}, align 4
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %base = shl nuw nsw i64 %iv, 1
  %v0 = add nsw i32 %a, 1
  %p0 = getelementptr inbounds i32, ptr %dst, i64 %base
  store i32 %v0, ptr %p0, align 4
  %v1 = add nsw i32 %a, 1
  %p1 = getelementptr inbounds i32, ptr %p0, i64 1
  store i32 %v1, ptr %p1, align 4
  %iv.next = add nuw nsw i64 %iv, 1
  %done = icmp eq i64 %iv.next, 100
  br i1 %done, label %exit, label %loop

exit:
  ret void
}
