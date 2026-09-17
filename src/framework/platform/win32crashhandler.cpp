/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "framework/core/application.h"
#if defined(WIN32) && defined(CRASH_HANDLER)

#include <windows.h>

#ifdef _MSC_VER

#pragma warning (push)
#pragma warning (disable:4091) // warning C4091: 'typedef ': ignored on left of '' when no variable is declared
#include <imagehlp.h>
#pragma warning (pop)

#else

#include <imagehlp.h>

#endif

#include <framework/core/graphicalapplication.h>
#include <framework/core/resourcemanager.h>

#include <algorithm>
#include <filesystem>
#include <vector>

namespace
{
std::string crashTimestamp()
{
    SYSTEMTIME time{};
    GetLocalTime(&time);
    return fmt::format("{:04}{:02}{:02}-{:02}{:02}{:02}",
        time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute, time.wSecond);
}

std::filesystem::path diagnosticsDirectory()
{
    std::error_code error;
    auto base = g_resources.getWriteDir().empty()
        ? std::filesystem::current_path(error)
        : std::filesystem::path(g_resources.getWriteDir());
    auto directory = base / "diagnostics";
    std::filesystem::create_directories(directory, error);
    return directory;
}

void pruneOldCrashFiles(const std::filesystem::path& directory, const std::string& extension, const std::size_t keep)
{
    std::error_code error;
    std::vector<std::filesystem::directory_entry> files;
    for (const auto& entry : std::filesystem::directory_iterator(directory, error)) {
        if (error)
            break;
        const auto name = entry.path().filename().string();
        if (entry.is_regular_file(error) && name.starts_with("crash-") && entry.path().extension() == extension)
            files.push_back(entry);
    }

    std::ranges::sort(files, [](const auto& left, const auto& right) {
        std::error_code leftError;
        std::error_code rightError;
        return left.last_write_time(leftError) > right.last_write_time(rightError);
    });

    for (std::size_t index = keep; index < files.size(); ++index)
        std::filesystem::remove(files[index].path(), error);
}

bool writeMiniDump(const std::filesystem::path& fileName, LPEXCEPTION_POINTERS exception)
{
    const HANDLE file = CreateFileW(fileName.wstring().c_str(), GENERIC_WRITE, 0, nullptr,
        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE)
        return false;

    MINIDUMP_EXCEPTION_INFORMATION information{};
    information.ThreadId = GetCurrentThreadId();
    information.ExceptionPointers = exception;
    information.ClientPointers = FALSE;
    const BOOL written = MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), file,
        MiniDumpNormal, &information, nullptr, nullptr);
    CloseHandle(file);
    return written == TRUE;
}
} // namespace

const char* getExceptionName(const DWORD exceptionCode)
{
    switch (exceptionCode) {
        case EXCEPTION_ACCESS_VIOLATION:         return "Access violation";
        case EXCEPTION_DATATYPE_MISALIGNMENT:    return "Datatype misalignment";
        case EXCEPTION_BREAKPOINT:               return "Breakpoint";
        case EXCEPTION_SINGLE_STEP:              return "Single step";
        case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:    return "Array bounds exceeded";
        case EXCEPTION_FLT_DENORMAL_OPERAND:     return "Float denormal operand";
        case EXCEPTION_FLT_DIVIDE_BY_ZERO:       return "Float divide by zero";
        case EXCEPTION_FLT_INEXACT_RESULT:       return "Float inexact result";
        case EXCEPTION_FLT_INVALID_OPERATION:    return "Float invalid operation";
        case EXCEPTION_FLT_OVERFLOW:             return "Float overflow";
        case EXCEPTION_FLT_STACK_CHECK:          return "Float stack check";
        case EXCEPTION_FLT_UNDERFLOW:            return "Float underflow";
        case EXCEPTION_INT_DIVIDE_BY_ZERO:       return "Integer divide by zero";
        case EXCEPTION_INT_OVERFLOW:             return "Integer overflow";
        case EXCEPTION_PRIV_INSTRUCTION:         return "Privileged instruction";
        case EXCEPTION_IN_PAGE_ERROR:            return "In page error";
        case EXCEPTION_ILLEGAL_INSTRUCTION:      return "Illegal instruction";
        case EXCEPTION_NONCONTINUABLE_EXCEPTION: return "Noncontinuable exception";
        case EXCEPTION_STACK_OVERFLOW:           return "Stack overflow";
        case EXCEPTION_INVALID_DISPOSITION:      return "Invalid disposition";
        case EXCEPTION_GUARD_PAGE:               return "Guard page";
        case EXCEPTION_INVALID_HANDLE:           return "Invalid handle";
    }
    return "Unknown exception";
}

void Stacktrace(LPEXCEPTION_POINTERS e, std::stringstream& ss)
{
    STACKFRAME sf;
    HANDLE process, thread;
    ULONG_PTR dwModBase, Disp;
    BOOL more = FALSE;
    DWORD machineType;
    int count = 0;
    char modname[MAX_PATH];
    char symBuffer[sizeof(IMAGEHLP_SYMBOL) + 255];

    auto* pSym = (PIMAGEHLP_SYMBOL)symBuffer;

    ZeroMemory(&sf, sizeof(sf));
#ifdef _WIN64
    sf.AddrPC.Offset = e->ContextRecord->Rip;
    sf.AddrStack.Offset = e->ContextRecord->Rsp;
    sf.AddrFrame.Offset = e->ContextRecord->Rbp;
    machineType = IMAGE_FILE_MACHINE_AMD64;
#else
    sf.AddrPC.Offset = e->ContextRecord->Eip;
    sf.AddrStack.Offset = e->ContextRecord->Esp;
    sf.AddrFrame.Offset = e->ContextRecord->Ebp;
    machineType = IMAGE_FILE_MACHINE_I386;
#endif

    sf.AddrPC.Mode = AddrModeFlat;
    sf.AddrStack.Mode = AddrModeFlat;
    sf.AddrFrame.Mode = AddrModeFlat;

    process = GetCurrentProcess();
    thread = GetCurrentThread();

    while (true) {
        more = StackWalk(machineType, process, thread, &sf, e->ContextRecord, nullptr, SymFunctionTableAccess, SymGetModuleBase, nullptr);
        if (!more || sf.AddrFrame.Offset == 0)
            break;

        dwModBase = SymGetModuleBase(process, sf.AddrPC.Offset);
        if (dwModBase)
            GetModuleFileName(reinterpret_cast<HINSTANCE>(dwModBase), modname, MAX_PATH);
        else {
#ifdef _MSC_VER
            strcpy_s(modname, sizeof(modname), "Unknown");
#else
            strncpy(modname, "Unknown", sizeof(modname));
            modname[sizeof(modname) - 1] = '\0';
#endif
        }

        Disp = 0;
        pSym->SizeOfStruct = sizeof(IMAGEHLP_SYMBOL);
        pSym->MaxNameLength = 254;

        if (SymGetSymFromAddr(process, sf.AddrPC.Offset, &Disp, pSym))
            ss << fmt::format("    {}: {}({}+%#0lx) [0x%016lX]\n", count, modname, pSym->Name, Disp, sf.AddrPC.Offset);
        else
            ss << fmt::format("    {}: {} [0x%016lX]\n", count, modname, sf.AddrPC.Offset);
        ++count;
    }
}

LONG CALLBACK ExceptionHandler(const LPEXCEPTION_POINTERS e)
{
    SymInitialize(GetCurrentProcess(), nullptr, TRUE);

    std::string crashReport = fmt::format(
        "== application crashed\n"
        "app name: {}\n"
        "app version: {}\n"
        "build compiler: {} - {}\n"
        "build date: {}\n"
        "build type: {}\n"
        "build revision: {} ({})\n"
        "crash date: {}\n"
        "exception: {} (0x{:08X})\n"
        "exception address: 0x{:016X}\n"
        "  backtrace:\n",
        g_app.getName(),
        g_app.getVersion(),
        g_app.getBuildCompiler(), g_app.getBuildArch(),
        g_app.getBuildDate(),
        g_app.getBuildType(),
        g_app.getBuildRevision(), g_app.getBuildCommit(),
        stdext::date_time_string(),
        getExceptionName(e->ExceptionRecord->ExceptionCode), e->ExceptionRecord->ExceptionCode,
        reinterpret_cast<std::uintptr_t>(e->ExceptionRecord->ExceptionAddress)
    );

    std::stringstream oss;
    oss << crashReport;
    Stacktrace(e, oss);
    oss << "\n";

    SymCleanup(GetCurrentProcess());

    g_logger.info(oss.str());

    const auto directory = diagnosticsDirectory();
    const auto timestamp = crashTimestamp();
    const auto reportPath = directory / fmt::format("crash-{}.log", timestamp);
    const auto dumpPath = directory / fmt::format("crash-{}.dmp", timestamp);

    std::ofstream fout(reportPath, std::ios::out | std::ios::trunc);
    if (fout.is_open()) {
        fout << oss.str();
        fout.close();
        g_logger.info("Crash report saved to file {}", reportPath.string());
    } else {
        g_logger.error("Failed to save crash report to {}", reportPath.string());
    }

    if (writeMiniDump(dumpPath, e))
        g_logger.info("Crash minidump saved to file {}", dumpPath.string());
    else
        g_logger.error("Failed to save crash minidump to {} (Windows error {})", dumpPath.string(), GetLastError());

    pruneOldCrashFiles(directory, ".log", 10);
    pruneOldCrashFiles(directory, ".dmp", 3);

    std::string msg = fmt::format(
        "The application has crashed.\n\n"
        "A crash report and minidump have been written to:\n{}",
        directory.string()
    );
    MessageBoxA(nullptr, msg.c_str(), "Application crashed", MB_OK | MB_ICONERROR);

    return EXCEPTION_CONTINUE_SEARCH;
}

void installCrashHandler()
{
    SetUnhandledExceptionFilter(ExceptionHandler);
}

#endif
