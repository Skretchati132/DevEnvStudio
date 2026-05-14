using System;
using System.Diagnostics;
using System.IO;

class Program
{
    static void Main()
    {
        string scriptPath = Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory,
            "script.ps1"
        );

        if (!File.Exists(scriptPath))
            return;

        ProcessStartInfo psi = new ProcessStartInfo()
        {
            FileName = "powershell.exe",

            Arguments =
                $"-ExecutionPolicy Bypass " +
                $"-WindowStyle Hidden " +
                $"-STA " +
                $"-File \"{scriptPath}\"",

            UseShellExecute = false,
            CreateNoWindow = true
        };

        Process.Start(psi);
    }
}