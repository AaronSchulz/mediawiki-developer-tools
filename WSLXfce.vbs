args = "-c" & " -l " & " -i " & """NO_AT_BRIDGE=1 LIBGL_ALWAYS_INDIRECT=1 DISPLAY=$(awk '/nameserver / {print $2; exit}' /etc/resolv.conf 2>/dev/null):0 startxfce4"""
WScript.CreateObject("Shell.Application").ShellExecute "bash", args, "", "open", 0
