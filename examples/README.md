# Examples

Minimal projects to verify the LEANWIN build box works. Each one uploads sources, builds, and downloads the artifact via the HTTP build server on port 2224.

| Example | Toolchain | Artifact |
|---------|-----------|----------|
| [hello-rust](hello-rust/) | Rust (MSVC target) | `hello-rust.exe` |
| [hello-dotnet](hello-dotnet/) | .NET Framework 4.8 + csc | `hello-dotnet.exe` |

Each example has a `build.sh` you run from the host.
