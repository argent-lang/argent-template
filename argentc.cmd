@echo off
setlocal

if defined ARGENT_TEMPLATE_ARGENT_DIR (
    set "ARGENT_DIR=%ARGENT_TEMPLATE_ARGENT_DIR%"
) else (
    set "ARGENT_DIR=%~dp0..\argent"
)

if not exist "%ARGENT_DIR%\Cargo.toml" (
    echo error: Argent checkout not found at %ARGENT_DIR% 1>&2
    echo run setup.cmd first or set ARGENT_TEMPLATE_ARGENT_DIR 1>&2
    exit /b 1
)

cargo run --quiet --manifest-path "%ARGENT_DIR%\Cargo.toml" --bin argentc -- %*
exit /b %errorlevel%
