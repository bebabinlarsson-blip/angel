# Debug adapter troubleshooting

The message

```
Failed to start Debug adapter server on port 6006: Can't create
```

comes from Godot's editor/debug adapter before the Angel scene runs. It means another Godot instance, an IDE adapter, or a stale debugger already owns port 6006. It is not produced by the Angel gameplay scripts.

Use `start_godot_debug.bat` to start the editor. It checks the requested adapter port and automatically advances to the next free port. You can also request a starting port explicitly:

```
start_godot_debug.bat 6006
```

If the error appears while launching Godot from an IDE, change that IDE's Godot debug-adapter port to the free port printed by the launcher, or close the stale Godot/adapter process first. On Windows, inspect the owner without terminating anything:

```
Get-NetTCPConnection -LocalPort 6006 -State Listen
Get-Process -Id <OwningProcess>
```

Only stop the process if it is a stale Godot/debugger instance you started. The web export server is separate and uses port 8060 by default; `serve_web.py` already selects the next free HTTP port when needed.
