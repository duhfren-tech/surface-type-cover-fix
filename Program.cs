using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;

// Launcher for TypeCoverFix.ps1: self-elevates, unpacks the embedded script, runs it and keeps the console open.
namespace TypeCoverFix
{
    internal static class Program
    {
        private const string ScriptResource = "TypeCoverFix.ps1";

        private static void Main(string[] args)
        {
            // relaunch with admin rights if needed
            if (!IsAdministrator())
            {
                try
                {
                    var psi = new ProcessStartInfo(Assembly.GetExecutingAssembly().Location)
                    {
                        Verb = "runas",
                        UseShellExecute = true,
                        Arguments = string.Join(" ", args)
                    };
                    Process.Start(psi);
                    return;
                }
                catch (Exception ex)
                {
                    Console.WriteLine("Elevation was declined, nothing changed. " + ex.Message);
                    Pause();
                    return;
                }
            }

            string script = ExtractScript();
            if (script == null)
            {
                Console.WriteLine("Embedded script is missing from the executable.");
                Pause();
                return;
            }

            int exit = RunScript(script);

            Console.WriteLine();
            Console.WriteLine(exit == 0
                ? "Finished. The Type Cover power management is disabled; keep this window for reference if you like."
                : "Finished with errors, see the output above.");
            Console.WriteLine("Log file: " + Path.Combine(AppDirectory, "type-cover-fix.log"));
            Pause();
        }

        private static string AppDirectory
        {
            get { return Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); }
        }

        private static bool IsAdministrator()
        {
            using (var identity = WindowsIdentity.GetCurrent())
            {
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
        }

        private static string ExtractScript()
        {
            var asm = Assembly.GetExecutingAssembly();
            var name = Array.Find(asm.GetManifestResourceNames(), n => n.EndsWith(ScriptResource, StringComparison.OrdinalIgnoreCase));
            if (name == null) return null;

            using (var stream = asm.GetManifestResourceStream(name))
            using (var reader = new StreamReader(stream, Encoding.UTF8))
            {
                string text = reader.ReadToEnd();
                string path = Path.Combine(Path.GetTempPath(), "TypeCoverFix-" + Guid.NewGuid().ToString("N") + ".ps1");
                File.WriteAllText(path, text, new UTF8Encoding(true));   // BOM keeps PowerShell happy
                return path;
            }
        }

        private static int RunScript(string scriptPath)
        {
            var psi = new ProcessStartInfo("powershell.exe",
                "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\"")
            {
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            var output = new StringBuilder();
            using (var process = new Process { StartInfo = psi })
            {
                process.OutputDataReceived += (s, e) => { if (e.Data != null) { Console.WriteLine(e.Data); output.AppendLine(e.Data); } };
                process.ErrorDataReceived += (s, e) => { if (e.Data != null) { Console.WriteLine(e.Data); output.AppendLine(e.Data); } };
                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                process.WaitForExit();
                try { File.WriteAllText(Path.Combine(AppDirectory, "type-cover-fix.log"), output.ToString(), new UTF8Encoding(true)); }
                catch { }
                return process.ExitCode;
            }
        }

        private static void Pause()
        {
            Console.WriteLine();
            Console.Write("Press any key to close... ");
            try { Console.ReadKey(true); } catch { }
        }
    }
}
