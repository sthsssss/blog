; ModuleID = './machine_cases.cpp'
source_filename = "/mnt/c/Users/sthy/Documents/Obsidian Vault/C++ GPU \EA\B8\B0\EC\B4\88/\ED\8F\AC\EC\9D\B8\ED\84\B0\EC\99\80 \EA\B0\92 \EC\9D\98\EB\AF\B8\EB\A1\A0/examples/commute/machine_cases.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%struct.IntView = type { ptr }
%struct.Big = type { [8 x i32] }

@constinit = private unnamed_addr constant [8 x i32] [i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8], align 4

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i32 @copy_int(i32 noundef %original) local_unnamed_addr #0 {
entry:
  %add = add nsw i32 %original, 1
  ret i32 %add
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable
define dso_local i32 @read_pointer(ptr nocapture noundef readonly %p) local_unnamed_addr #2 {
entry:
  %0 = load i32, ptr %p, align 4, !tbaa !5
  ret i32 %0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef ptr @pointer_identity(ptr noundef readnone returned %p) local_unnamed_addr #0 {
entry:
  ret ptr %p
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write) uwtable
define dso_local void @set_reference(ptr nocapture noundef nonnull writeonly align 4 dereferenceable(4) %value) local_unnamed_addr #3 {
entry:
  store i32 100, ptr %value, align 4, !tbaa !5
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable
define dso_local i32 @read_const_reference(ptr nocapture noundef nonnull readonly align 4 dereferenceable(4) %value) local_unnamed_addr #2 {
entry:
  %0 = load i32, ptr %value, align 4, !tbaa !5
  ret i32 %0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i32 @gradient_by_value(i64 %value.coerce) local_unnamed_addr #0 {
entry:
  %value.sroa.0.0.extract.trunc = trunc i64 %value.coerce to i32
  ret i32 %value.sroa.0.0.extract.trunc
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable
define dso_local i64 @_Z13copy_gradientRK8Gradient(ptr nocapture noundef nonnull readonly align 4 dereferenceable(8) %source) local_unnamed_addr #2 {
entry:
  %retval.sroa.0.0.copyload = load i64, ptr %source, align 4, !tbaa.struct !9
  ret i64 %retval.sroa.0.0.copyload
}

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #4

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef nonnull align 4 dereferenceable(8) ptr @_Z12ref_gradientR8Gradient(ptr noundef nonnull readnone returned align 4 dereferenceable(8) %source) local_unnamed_addr #0 {
entry:
  ret ptr %source
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i32 @local_reference(i32 noundef %x) local_unnamed_addr #0 {
entry:
  %add = add nsw i32 %x, 1
  ret i32 %add
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i32 @member_reference(i32 noundef %x) local_unnamed_addr #0 {
entry:
  %add = add nsw i32 %x, 1
  ret i32 %add
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable
define dso_local i32 @dynamic_reference(i1 noundef zeroext %choose_a, ptr nocapture noundef nonnull readonly align 4 dereferenceable(4) %a, ptr nocapture noundef nonnull readonly align 4 dereferenceable(4) %b) local_unnamed_addr #2 {
entry:
  %a.val = load i32, ptr %a, align 4
  %b.val = load i32, ptr %b, align 4
  %0 = select i1 %choose_a, i32 %a.val, i32 %b.val
  ret i32 %0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none) uwtable
define dso_local i32 @read_existing(ptr nocapture noundef nonnull readonly align 8 dereferenceable(8) %view) local_unnamed_addr #5 {
entry:
  %0 = load ptr, ptr %view, align 8, !tbaa !10
  %1 = load i32, ptr %0, align 4, !tbaa !5
  ret i32 %1
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i32 @inlined_call(i32 noundef %x) local_unnamed_addr #0 {
entry:
  %add = add nsw i32 %x, 1
  ret i32 %add
}

; Function Attrs: mustprogress uwtable
define dso_local void @materialize_for_call(ptr noundef nonnull align 4 dereferenceable(4) %x) local_unnamed_addr #6 {
entry:
  %view = alloca %struct.IntView, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %view) #9
  store ptr %x, ptr %view, align 8, !tbaa !13
  call void @observe(ptr noundef nonnull align 8 dereferenceable(8) %view)
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %view) #9
  ret void
}

declare void @observe(ptr noundef nonnull align 8 dereferenceable(8)) local_unnamed_addr #7

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i32 @pointer_equivalent(i32 noundef %x) local_unnamed_addr #0 {
entry:
  %add = add nsw i32 %x, 1
  ret i32 %add
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable
define dso_local i32 @by_value_view(ptr nocapture readonly %view.coerce) local_unnamed_addr #2 {
entry:
  %0 = load i32, ptr %view.coerce, align 4, !tbaa !5
  ret i32 %0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i64 @view_size() local_unnamed_addr #0 {
entry:
  ret i64 8
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) uwtable
define dso_local void @_Z8make_bigv(ptr dead_on_unwind noalias nocapture writable writeonly sret(%struct.Big) align 4 %agg.result) local_unnamed_addr #8 {
entry:
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 4 dereferenceable(32) %agg.result, ptr noundef nonnull align 4 dereferenceable(32) @constinit, i64 32, i1 false), !tbaa.struct !14
  ret void
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #3 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { mustprogress nofree norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #6 = { mustprogress uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #7 = { "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #8 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #9 = { nounwind }

!llvm.linker.options = !{}
!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 18.1.3 (1ubuntu1)"}
!5 = !{!6, !6, i64 0}
!6 = !{!"int", !7, i64 0}
!7 = !{!"omnipotent char", !8, i64 0}
!8 = !{!"Simple C++ TBAA"}
!9 = !{i64 0, i64 4, !5, i64 4, i64 4, !5}
!10 = !{!11, !12, i64 0}
!11 = !{!"_ZTS7IntView", !12, i64 0}
!12 = !{!"any pointer", !7, i64 0}
!13 = !{!12, !12, i64 0}
!14 = !{i64 0, i64 32, !15}
!15 = !{!7, !7, i64 0}
