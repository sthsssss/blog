; ModuleID = './artifacts/raw.ll'
source_filename = "/mnt/c/Users/sthy/Documents/Obsidian Vault/C++ GPU \EA\B8\B0\EC\B4\88/\ED\8F\AC\EC\9D\B8\ED\84\B0\EC\99\80 \EA\B0\92 \EC\9D\98\EB\AF\B8\EB\A1\A0/examples/commute/machine_cases.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%struct.Gradient = type { i32, i32 }
%struct.IntView = type { ptr }
%struct.Big = type { [8 x i32] }

@constinit = private constant [8 x i32] [i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8], align 4

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @copy_int(i32 noundef %original) #0 {
entry:
  %add = add nsw i32 %original, 1
  ret i32 %add
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) #1

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @read_pointer(ptr noundef %p) #0 {
entry:
  %0 = load i32, ptr %p, align 4, !tbaa !5
  ret i32 %0
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local ptr @pointer_identity(ptr noundef %p) #0 {
entry:
  ret ptr %p
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local void @set_reference(ptr noundef nonnull align 4 dereferenceable(4) %value) #0 {
entry:
  store i32 100, ptr %value, align 4, !tbaa !5
  ret void
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @read_const_reference(ptr noundef nonnull align 4 dereferenceable(4) %value) #0 {
entry:
  %0 = load i32, ptr %value, align 4, !tbaa !5
  ret i32 %0
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @gradient_by_value(i64 %value.coerce) #0 {
entry:
  %value = alloca %struct.Gradient, align 4
  store i64 %value.coerce, ptr %value, align 4
  %start = getelementptr inbounds %struct.Gradient, ptr %value, i32 0, i32 0
  %0 = load i32, ptr %start, align 4, !tbaa !9
  ret i32 %0
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i64 @_Z13copy_gradientRK8Gradient(ptr noundef nonnull align 4 dereferenceable(8) %source) #0 {
entry:
  %retval = alloca %struct.Gradient, align 4
  call void @llvm.memcpy.p0.p0.i64(ptr align 4 %retval, ptr align 4 %source, i64 8, i1 false), !tbaa.struct !11
  %0 = load i64, ptr %retval, align 4
  ret i64 %0
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #2

; Function Attrs: mustprogress nounwind uwtable
define dso_local noundef nonnull align 4 dereferenceable(8) ptr @_Z12ref_gradientR8Gradient(ptr noundef nonnull align 4 dereferenceable(8) %source) #0 {
entry:
  ret ptr %source
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @local_reference(i32 noundef %x) #0 {
entry:
  %add = add nsw i32 %x, 1
  ret i32 %add
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @member_reference(i32 noundef %x) #0 {
entry:
  %x.addr = alloca i32, align 4
  %view = alloca %struct.IntView, align 8
  store i32 %x, ptr %x.addr, align 4, !tbaa !5
  call void @llvm.lifetime.start.p0(i64 8, ptr %view) #5
  %value = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  store ptr %x.addr, ptr %value, align 8, !tbaa !12
  %value1 = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  %0 = load ptr, ptr %value1, align 8, !tbaa !14
  %1 = load i32, ptr %0, align 4, !tbaa !5
  %add = add nsw i32 %1, 1
  call void @llvm.lifetime.end.p0(i64 8, ptr %view) #5
  ret i32 %add
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @dynamic_reference(i1 noundef zeroext %choose_a, ptr noundef nonnull align 4 dereferenceable(4) %a, ptr noundef nonnull align 4 dereferenceable(4) %b) #0 {
entry:
  %view = alloca %struct.IntView, align 8
  %frombool = zext i1 %choose_a to i8
  call void @llvm.lifetime.start.p0(i64 8, ptr %view) #5
  %value = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  %tobool = trunc i8 %frombool to i1
  br i1 %tobool, label %cond.true, label %cond.false

cond.true:                                        ; preds = %entry
  br label %cond.end

cond.false:                                       ; preds = %entry
  br label %cond.end

cond.end:                                         ; preds = %cond.false, %cond.true
  %cond-lvalue = phi ptr [ %a, %cond.true ], [ %b, %cond.false ]
  store ptr %cond-lvalue, ptr %value, align 8, !tbaa !12
  %value1 = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  %0 = load ptr, ptr %value1, align 8, !tbaa !14
  %1 = load i32, ptr %0, align 4, !tbaa !5
  call void @llvm.lifetime.end.p0(i64 8, ptr %view) #5
  ret i32 %1
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @read_existing(ptr noundef nonnull align 8 dereferenceable(8) %view) #0 {
entry:
  %value = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  %0 = load ptr, ptr %value, align 8, !tbaa !14
  %1 = load i32, ptr %0, align 4, !tbaa !5
  ret i32 %1
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @inlined_call(i32 noundef %x) #0 {
entry:
  %x.addr = alloca i32, align 4
  %view = alloca %struct.IntView, align 8
  store i32 %x, ptr %x.addr, align 4, !tbaa !5
  call void @llvm.lifetime.start.p0(i64 8, ptr %view) #5
  %value = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  store ptr %x.addr, ptr %value, align 8, !tbaa !12
  %call = call i32 @read_existing(ptr noundef nonnull align 8 dereferenceable(8) %view)
  %add = add nsw i32 %call, 1
  call void @llvm.lifetime.end.p0(i64 8, ptr %view) #5
  ret i32 %add
}

; Function Attrs: mustprogress uwtable
define dso_local void @materialize_for_call(ptr noundef nonnull align 4 dereferenceable(4) %x) #3 {
entry:
  %view = alloca %struct.IntView, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %view) #5
  %value = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  store ptr %x, ptr %value, align 8, !tbaa !12
  call void @observe(ptr noundef nonnull align 8 dereferenceable(8) %view)
  call void @llvm.lifetime.end.p0(i64 8, ptr %view) #5
  ret void
}

declare void @observe(ptr noundef nonnull align 8 dereferenceable(8)) #4

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @pointer_equivalent(i32 noundef %x) #0 {
entry:
  %add = add nsw i32 %x, 1
  ret i32 %add
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i32 @by_value_view(ptr %view.coerce) #0 {
entry:
  %view = alloca %struct.IntView, align 8
  %coerce.dive = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  store ptr %view.coerce, ptr %coerce.dive, align 8
  %value = getelementptr inbounds %struct.IntView, ptr %view, i32 0, i32 0
  %0 = load ptr, ptr %value, align 8, !tbaa !14
  %1 = load i32, ptr %0, align 4, !tbaa !5
  ret i32 %1
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local i64 @view_size() #0 {
entry:
  ret i64 8
}

; Function Attrs: mustprogress nounwind uwtable
define dso_local void @_Z8make_bigv(ptr dead_on_unwind noalias writable sret(%struct.Big) align 4 %agg.result) #0 {
entry:
  %values = getelementptr inbounds %struct.Big, ptr %agg.result, i32 0, i32 0
  %arrayinit.begin = getelementptr inbounds [8 x i32], ptr %values, i64 0, i64 0
  call void @llvm.memcpy.p0.p0.i64(ptr align 4 %values, ptr align 4 @constinit, i64 32, i1 false), !tbaa.struct !16
  ret void
}

attributes #0 = { mustprogress nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { mustprogress uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #5 = { nounwind }

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
!9 = !{!10, !6, i64 0}
!10 = !{!"_ZTS8Gradient", !6, i64 0, !6, i64 4}
!11 = !{i64 0, i64 4, !5, i64 4, i64 4, !5}
!12 = !{!13, !13, i64 0}
!13 = !{!"any pointer", !7, i64 0}
!14 = !{!15, !13, i64 0}
!15 = !{!"_ZTS7IntView", !13, i64 0}
!16 = !{i64 0, i64 32, !17}
!17 = !{!7, !7, i64 0}
