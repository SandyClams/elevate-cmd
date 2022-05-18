## Elevate cmd.exe
simple batch script that replaces the current cmd window with an equivalent Administrator cmd window by way of calling into Powershell. The original cmd window is destroyed, and the new Administrator cmd window is opened in the same directory, with the same environment variables, and with the same PUSHD stack.

**Usage be like**  
just throw it in your PATH and call `elevate` and poof.

**Which Powershell?**  
it presumably works for any version of Powershell, meaning it should work out-of-the-box on any Windows installation. I tested it on Powershell v1.0 and v7.1.
