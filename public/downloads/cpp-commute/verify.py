#!/usr/bin/env python3
"""Rebuild the book's examples and preserve compiler evidence as text artifacts."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
ARTIFACTS = ROOT / "artifacts"


def run(command, env=None):
    return subprocess.run([str(x) for x in command], env=env,
                          capture_output=True, text=True, timeout=60)


def require_success(result, label):
    if result.returncode:
        raise RuntimeError(label + "\n" + result.stdout + result.stderr)


def function_body(ir, name):
    found = re.search(r"^define [^\n]*@" + name + r"\([^\n]*\).*?^}", ir, re.M | re.S)
    if not found:
        raise RuntimeError("Missing IR function: " + name)
    return found.group(0)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clang")
    parser.add_argument("--opt")
    args = parser.parse_args()
    clang = args.clang or shutil.which("clang++-18") or shutil.which("clang++")
    opt = args.opt or shutil.which("opt-18") or shutil.which("opt")
    env = os.environ.copy()
    location = Path("/tmp/clang-reference-study-location")
    if not clang and location.exists():
        toolchain = Path(location.read_text().strip()) / "toolchain/usr"
        clang = str(toolchain / "bin/clang++-18")
        opt = opt or str(toolchain / "bin/opt-18")
        libraries = [toolchain / "lib/x86_64-linux-gnu", toolchain / "lib/llvm-18/lib"]
        if env.get("LD_LIBRARY_PATH"):
            libraries.append(Path(env["LD_LIBRARY_PATH"]))
        env["LD_LIBRARY_PATH"] = ":".join(str(x) for x in libraries)
    if not clang or not opt:
        raise RuntimeError("Supply --clang and --opt for a matching Clang/LLVM installation.")
    ARTIFACTS.mkdir(exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix="cpp-commute-"))
    report = {"time": datetime.datetime.now().astimezone().isoformat(),
              "standard": "C++20", "runs": [], "elision": [], "negative": [], "warnings": []}
    compilers = [("Clang", clang, env)]
    if shutil.which("g++"):
        compilers.append(("GCC", shutil.which("g++"), os.environ.copy()))
    for label, compiler, compiler_env in compilers:
        version = run([compiler, "--version"], compiler_env)
        require_success(version, "compiler version")
        report[label + "_version"] = version.stdout.splitlines()[0]
        for source in sorted(ROOT.glob("[0-9][0-9]_*.cpp")):
            binary = build / (label + source.stem)
            sources = [source]
            if source.name == "12_optimizer.cpp":
                sources.append(ROOT / "machine_cases.cpp")
            command = [compiler, "-std=c++20", "-O2", "-Wall", "-Wextra", "-Wpedantic", *sources, "-o", binary]
            compiled = run(command, compiler_env)
            require_success(compiled, str(source))
            if compiled.stderr:
                if (source.name == "09_lifetime.cpp" and "-Wdangling-reference" in compiled.stderr
                        and compiled.stderr.count("warning:") == 1):
                    report["warnings"].append({"compiler": label,
                        "case": "temporary forwarded through a reference-returning function; target not accessed",
                        "diagnostic": compiled.stderr})
                else:
                    raise RuntimeError("Unexpected compiler diagnostic: " + compiled.stderr)
            executed = run([binary], compiler_env)
            require_success(executed, str(binary))
            report["runs"].append({"compiler": label, "source": source.name,
                                   "flags": "-std=c++20 -O2 -Wall -Wextra -Wpedantic",
                                   "stdout": executed.stdout, "exit": executed.returncode})
        for optimization in ["-O0", "-O2"]:
            for no_elision in [False, True]:
                flags = [optimization] + (["-fno-elide-constructors"] if no_elision else [])
                binary = build / (label + "elision" + optimization + str(no_elision))
                compiled = run([compiler, "-std=c++20", *flags, ROOT / "11_elision.cpp", "-o", binary], compiler_env)
                require_success(compiled, "elision build")
                executed = run([binary], compiler_env)
                require_success(executed, "elision run")
                report["elision"].append({"compiler": label, "flags": flags, "stdout": executed.stdout})

    base = '#include "gradient.hpp"\n#include <utility>\nGradient make(){return Gradient{0,255};}\n'
    negative = {
        "const_object_write": 'int main(){const Gradient g{0,255};g.start=1;}',
        "const_reference_write": 'int main(){Gradient g{0,255};const Gradient& r=g;r.start=1;}',
        "pointer_to_const_write": 'int main(){Gradient g{0,255};const Gradient* p=&g;p->start=1;}',
        "const_pointer_redirect": 'int main(){Gradient a{0,255},b{1,2};Gradient* const p=&a;p=&b;}',
        "const_owned_member": 'struct Owner{Gradient data;};int main(){const Owner o{{0,255}};o.data.start=1;}',
        "const_pointer_field": 'struct View{Gradient* p;};int main(){Gradient a{0,255},b{1,2};const View v{&a};v.p=&b;}',
        "lvalue_reference_to_prvalue": 'int main(){Gradient& r=make();}',
        "lvalue_reference_to_xvalue": 'int main(){Gradient g{0,255};Gradient& r=std::move(g);}',
        "rvalue_reference_to_lvalue": 'int main(){Gradient g{0,255};Gradient&& r=g;}',
        "mutable_reference_to_const": 'int main(){const Gradient g{0,255};Gradient& r=g;}',
        "move_const_to_mutable_rvalue_reference": 'int main(){const Gradient g{0,255};Gradient&& r=std::move(g);}',
        "const_owner_mutable_getter": 'struct Owner{Gradient data;Gradient& get()const{return data;}};',
        "const_named_is_not_assignable": 'int main(){const Gradient g{0,255};g=Gradient{1,2};}',
        "unique_owner_copy": '#include <memory>\nint main(){auto p=std::make_unique<int>(1);auto q=p;}',
        "reference_member_assignment": 'struct View{Gradient& data;};int main(){Gradient a{0,255},b{1,2};View x{a},y{b};x=y;}'
    }
    for label, compiler, compiler_env in compilers:
        for name, body in negative.items():
            source = build / (name + ".cpp")
            source.write_text(base + body + "\n")
            checked = run([compiler, "-std=c++20", "-I", ROOT, "-fsyntax-only", source], compiler_env)
            if checked.returncode == 0:
                raise RuntimeError("Expected rejection: " + name)
            report["negative"].append({"compiler": label, "case": name, "diagnostic": checked.stderr})
        immobile = build / "immobile.cpp"
        immobile.write_text('struct X{X(){};X(const X&)=delete;X(X&&)=delete;};X make(){return X{};}int main(){X x=make();}\n')
        compiled = run([compiler, "-std=c++20", "-fno-elide-constructors", immobile, "-o", build / (label + "immobile")], compiler_env)
        require_success(compiled, "guaranteed direct construction")
        executed = run([build / (label + "immobile")], compiler_env)
        require_success(executed, "immobile run")
        report[label + "_immobile_prvalue"] = "PASS with deleted copy/move and -fno-elide-constructors"
        bad = build / "bad_reference.cpp"
        bad.write_text(base + 'Gradient& bad(){Gradient local{0,255};return local;}\n')
        checked = run([compiler, "-std=c++20", "-Wall", "-I", ROOT, "-fsyntax-only", bad], compiler_env)
        require_success(checked, "dangling return diagnostic")
        if "warning:" not in checked.stderr:
            raise RuntimeError("Expected dangling return warning")
        report["warnings"].append({"compiler": label, "case": "dangling return; not executed", "diagnostic": checked.stderr})
        pessimizing = build / "pessimizing.cpp"
        pessimizing.write_text('#include <utility>\nstruct X{X(){};X(X&&){};};X make(){X x;return std::move(x);}\n')
        checked = run([compiler, "-std=c++20", "-Wall", "-Wpessimizing-move", "-fsyntax-only", pessimizing], compiler_env)
        require_success(checked, "pessimizing move diagnostic")
        if "warning:" not in checked.stderr:
            raise RuntimeError("Expected pessimizing move warning")
        report["warnings"].append({"compiler": label, "case": "return std::move(local)", "diagnostic": checked.stderr})

    machine = ROOT / "machine_cases.cpp"
    commands = [
        [clang, "-std=c++20", "-O1", "-Xclang", "-disable-llvm-passes", "-fno-discard-value-names", "-S", "-emit-llvm", machine, "-o", ARTIFACTS / "raw.ll"],
        [opt, "-S", "-passes=mem2reg", ARTIFACTS / "raw.ll", "-o", ARTIFACTS / "mem2reg.ll"],
        [opt, "-S", "-passes=sroa", ARTIFACTS / "raw.ll", "-o", ARTIFACTS / "sroa.ll"],
        [clang, "-std=c++20", "-O2", "-fno-discard-value-names", "-S", "-emit-llvm", machine, "-o", ARTIFACTS / "optimized.ll"],
        [clang, "-std=c++20", "-O0", "-S", "-masm=intel", machine, "-o", ARTIFACTS / "unoptimized.s"],
        [clang, "-std=c++20", "-O2", "-S", "-masm=intel", machine, "-o", ARTIFACTS / "optimized.s"],
        [clang, "-std=c++20", "-O2", "-fno-discard-value-names", "-S", "-emit-llvm", "-mllvm", "-print-before=sroa", "-mllvm", "-print-after=sroa", "-mllvm", "-filter-print-funcs=member_reference", machine, "-o", build / "traced.ll"]
    ]
    for command in commands:
        checked = run(command, env)
        require_success(checked, "LLVM evidence")
        if "-print-before=sroa" in command:
            (ARTIFACTS / "clang_sroa_trace.txt").write_text(checked.stderr)
    sroa = (ARTIFACTS / "sroa.ll").read_text()
    mem2reg = (ARTIFACTS / "mem2reg.ll").read_text()
    assert "alloca" not in function_body(sroa, "member_reference")
    assert "alloca" not in function_body(sroa, "dynamic_reference")
    assert "alloca" not in function_body(mem2reg, "local_reference")
    assert "alloca" in function_body(mem2reg, "member_reference")
    assert "alloca" in function_body(sroa, "materialize_for_call")
    report["IR_checks"] = "PASS: local promotion, aggregate promotion, runtime choice, retained external-call storage"

    cuda = shutil.which("nvcc") or "/usr/local/cuda-12.6/bin/nvcc"
    binary = build / "gpu_buffer"
    compiled = run([cuda, "-std=c++20", "-arch=sm_61", "-Xcompiler=-Wall,-Wextra", ROOT / "13_gpu_buffer.cu", "-o", binary])
    require_success(compiled, "CUDA build")
    executed = run([binary])
    require_success(executed, "CUDA execution")
    report["gpu"] = {"flags": "-std=c++20 -arch=sm_61 -Xcompiler=-Wall,-Wextra", "stdout": executed.stdout,
                     "exit": executed.returncode, "build_diagnostic": compiled.stderr}
    ptx = run([cuda, "-std=c++20", "-O2", "-arch=compute_61", "-ptx", ROOT / "13_gpu_buffer.cu", "-o", ARTIFACTS / "gpu_buffer.ptx"])
    require_success(ptx, "CUDA PTX generation")
    report["gpu"]["ptx"] = "gpu_buffer.ptx; virtual ISA, not final device machine code"
    report["source_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in sorted(ROOT.iterdir()) if p.suffix in [".cpp", ".cu", ".hpp", ".py"]}
    (ARTIFACTS / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("PASS:", len(report["runs"]), "CPU runs,", len(report["elision"]), "return-elision comparisons,",
          len(report["negative"]), "expected compiler errors, LLVM pass checks, and GPU execution")
    for label in ["Clang", "GCC"]:
        for entry in report["elision"]:
            if entry["compiler"] == label:
                print(label, " ".join(entry["flags"]), repr(entry["stdout"]))
    print("Artifacts:", ARTIFACTS)


if __name__ == "__main__":
    main()
