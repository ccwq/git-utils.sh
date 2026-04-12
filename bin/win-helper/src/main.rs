use std::env;
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process::{self, Command, ExitStatus, Stdio};

fn main() {
    if let Err(err) = run() {
        eprintln!("[win-helper] {err}");
        process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let mut args: Vec<OsString> = env::args_os().skip(1).collect();

    match args.first().and_then(|value| value.to_str()) {
        Some("--help" | "-h") => {
            print_help();
            return Ok(());
        }
        Some("--print-path") => {
            let bash_path = resolve_git_bash()?;
            println!("{}", bash_path.display());
            return Ok(());
        }
        _ => {}
    }

    let bash_path = resolve_git_bash()?;
    persist_git_bash_cache(&bash_path);

    // Keep the helper focused: it only resolves Git Bash and forwards argv.
    let status = if args.is_empty() {
        Command::new(&bash_path)
            .status()
            .map_err(|err| format!("failed to start {}: {err}", bash_path.display()))?
    } else {
        Command::new(&bash_path)
            .args(args.drain(..))
            .status()
            .map_err(|err| format!("failed to start {}: {err}", bash_path.display()))?
    };

    exit_with_status(status);
}

fn print_help() {
    println!("win-helper - Resolve and run Git Bash on Windows.");
    println!();
    println!("Usage:");
    println!("  win-helper --print-path");
    println!("  win-helper -lc \"echo hello\"");
    println!("  win-helper path\\to\\script.sh [args...]");
}

fn resolve_git_bash() -> Result<PathBuf, String> {
    if let Some(path) = read_env_path("GIT_BASH") {
        return Ok(path);
    }

    if let Some(path) = read_reg_cached_path() {
        return Ok(path);
    }

    if let Some(path) = resolve_from_where_git() {
        return Ok(path);
    }

    if let Some(path) = resolve_default_install_path() {
        return Ok(path);
    }

    Err("Cannot find Git Bash executable. Tried env cache, HKCU cache, where git, and default install paths.".to_string())
}

fn read_env_path(name: &str) -> Option<PathBuf> {
    let value = env::var_os(name)?;
    let path = PathBuf::from(value);
    path.is_file().then_some(path)
}

fn read_reg_cached_path() -> Option<PathBuf> {
    let output = Command::new("reg")
        .args(["query", r"HKCU\Environment", "/v", "GIT_BASH"])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        if !line.contains("REG_SZ") || !line.contains("GIT_BASH") {
            continue;
        }

        let value = line.split("REG_SZ").nth(1)?.trim();
        let path = PathBuf::from(value);
        if path.is_file() {
            return Some(path);
        }
    }

    None
}

fn resolve_from_where_git() -> Option<PathBuf> {
    let output = Command::new("where").arg("git").output().ok()?;
    if !output.status.success() {
        return None;
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines().map(str::trim).filter(|line| !line.is_empty()) {
        let git_path = PathBuf::from(line);
        if let Some(path) = bash_candidates_from_git(&git_path)
            .into_iter()
            .find(|candidate| candidate.is_file())
        {
            return Some(path);
        }
    }

    None
}

fn bash_candidates_from_git(git_path: &Path) -> Vec<PathBuf> {
    let Some(dir) = git_path.parent() else {
        return Vec::new();
    };

    let Some(root) = dir.parent() else {
        return Vec::new();
    };

    vec![
        root.join("bin").join("bash.exe"),
        root.join("usr").join("bin").join("bash.exe"),
    ]
}

fn resolve_default_install_path() -> Option<PathBuf> {
    let mut candidates = Vec::new();

    if let Some(program_files) = env::var_os("ProgramFiles") {
        let base = PathBuf::from(program_files).join("Git");
        candidates.push(base.join("bin").join("bash.exe"));
        candidates.push(base.join("usr").join("bin").join("bash.exe"));
    }

    if let Some(program_files_x86) = env::var_os("ProgramFiles(x86)") {
        let base = PathBuf::from(program_files_x86).join("Git");
        candidates.push(base.join("bin").join("bash.exe"));
        candidates.push(base.join("usr").join("bin").join("bash.exe"));
    }

    candidates.into_iter().find(|path| path.is_file())
}

fn persist_git_bash_cache(path: &Path) {
    env::set_var("GIT_BASH", path);

    let value = path.to_string_lossy().to_string();
    let _ = Command::new("setx")
        .args(["GIT_BASH", &value])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

fn exit_with_status(status: ExitStatus) -> ! {
    if let Some(code) = status.code() {
        process::exit(code);
    }

    process::exit(1);
}
