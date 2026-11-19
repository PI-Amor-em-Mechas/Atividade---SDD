using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

public static class LauncherSupervisor
{
    [StructLayout(LayoutKind.Sequential)]
    private struct BasicLimits
    {
        public long PerProcessUserTimeLimit, PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass, SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ExtendedLimits
    {
        public BasicLimits BasicLimitInformation;
        public ulong ReadOperationCount, WriteOperationCount, OtherOperationCount;
        public ulong ReadTransferCount, WriteTransferCount, OtherTransferCount;
        public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
    }

    private delegate bool Handler(uint signal);
    private static readonly Handler IgnoreInterrupt = delegate(uint signal) { return signal <= 1; };

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetInformationJobObject(IntPtr job, int kind, ref ExtendedLimits limits, int length);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll")]
    private static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool member);
    [DllImport("kernel32.dll")]
    private static extern uint GetConsoleProcessList(uint[] processes, uint count);
    [DllImport("kernel32.dll")]
    private static extern bool GenerateConsoleCtrlEvent(uint signal, uint group);
    [DllImport("kernel32.dll")]
    private static extern bool SetConsoleCtrlHandler(Handler handler, bool add);
    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);

    private static bool CanSignalConsole(IntPtr job)
    {
        uint[] ids = new uint[256];
        uint count = GetConsoleProcessList(ids, (uint)ids.Length);
        if (count == 0 || count > ids.Length) return false;
        for (int i = 0; i < count; i++)
        {
            try
            {
                using (Process process = Process.GetProcessById((int)ids[i]))
                {
                    bool member;
                    if (!IsProcessInJob(process.Handle, job, out member) || !member) return false;
                }
            }
            catch (ArgumentException) { }
            catch (InvalidOperationException) { return false; }
            catch (System.ComponentModel.Win32Exception) { return false; }
        }
        return true;
    }

    public static int Run(string executable, string arguments, string directory, string log, string id, string service)
    {
        string[] secrets = {
            Environment.GetEnvironmentVariable("DB_PASSWORD"),
            Environment.GetEnvironmentVariable("TRACKING_API_TOKEN")
        };
        object logLock = new object();
        Action<string> write = delegate(string line)
        {
            if (line == null) return;
            string tag = "";
            if (service == "Worker")
            {
                if (line.Contains("Ciclo iniciado")) tag = "[worker-ready] ";
                else if (line.Contains("Falha no ciclo") || line.Contains("Traceback")) tag = "[worker-error] ";
            }
            foreach (string secret in secrets)
                if (!String.IsNullOrEmpty(secret)) line = line.Replace(secret, "***");
            line = Regex.Replace(line, @"(?i)(\b(?:DB_PASSWORD|TRACKING_API_TOKEN)\s*[=:]\s*|\bBearer\s+)\S+", "$1***");
            line = Regex.Replace(line, @"(https?://)[^/\s@]+@", "$1***@");
            if (line.Length > 65536) line = line.Substring(0, 65536) + " [linha truncada]";
            lock (logLock)
            {
                try
                {
                    if (File.Exists(log) && new FileInfo(log).Length >= 1048576)
                    {
                        File.Delete(log + ".1");
                        File.Move(log, log + ".1");
                    }
                    File.AppendAllText(log, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss ") + tag + line + Environment.NewLine, new UTF8Encoding(false));
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        };

        var limits = new ExtendedLimits();
        limits.BasicLimitInformation.LimitFlags = 0x2000;
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero ||
            !SetInformationJobObject(job, 9, ref limits, Marshal.SizeOf(typeof(ExtendedLimits))) ||
            !AssignProcessToJobObject(job, Process.GetCurrentProcess().Handle))
        {
            int error = Marshal.GetLastWin32Error();
            if (job != IntPtr.Zero) CloseHandle(job);
            write("Falha ao isolar a arvore de processos. Codigo Windows: " + error);
            return 1;
        }

        // This process owns the job handle. Windows closes it on exit, including forced exit.
        try
        {
            using (var stop = new EventWaitHandle(false, EventResetMode.ManualReset, @"Local\Rastreio-" + id))
            using (var child = new Process())
            {
                if (stop.WaitOne(0)) return 0;
                var start = new ProcessStartInfo(executable, arguments);
                start.WorkingDirectory = directory;
                start.UseShellExecute = false;
                start.RedirectStandardOutput = true;
                start.RedirectStandardError = true;
                start.StandardOutputEncoding = new UTF8Encoding(false);
                start.StandardErrorEncoding = new UTF8Encoding(false);
                if (Path.GetExtension(executable).Equals(".cmd", StringComparison.OrdinalIgnoreCase) ||
                    Path.GetExtension(executable).Equals(".bat", StringComparison.OrdinalIgnoreCase))
                {
                    start.FileName = Environment.GetEnvironmentVariable("ComSpec");
                    start.Arguments = "/d /s /v:off /c \"\"%RASTREIO_LAUNCHER_TOOL%\" " + arguments + "\"";
                    start.EnvironmentVariables["RASTREIO_LAUNCHER_TOOL"] = executable;
                }
                child.StartInfo = start;
                child.OutputDataReceived += delegate(object sender, DataReceivedEventArgs data) { write(data.Data); };
                child.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs data) { write(data.Data); };
                SetConsoleCtrlHandler(IgnoreInterrupt, true);
                child.Start();
                child.BeginOutputReadLine();
                child.BeginErrorReadLine();
                write("Processo iniciado.");
                while (!child.HasExited)
                {
                    if (!stop.WaitOne(200)) continue;
                    bool signal = CanSignalConsole(job) && GenerateConsoleCtrlEvent(0, 0);
                    write(signal ? "Interrupcao de console solicitada." : "Console compartilhado ou indisponivel. Aguardando encerramento forcado controlado.");
                    child.WaitForExit();
                    break;
                }
                child.WaitForExit();
                write("Processo encerrou com codigo " + child.ExitCode);
                return child.ExitCode;
            }
        }
        catch (Exception ex)
        {
            write("Falha no supervisor: " + ex.GetType().Name);
            return 1;
        }
    }
}
