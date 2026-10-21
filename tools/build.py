"""Build the installable mod with no source-project wrapper directory."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mod"
NAME = "beamng_weather_hashk014.zip"


def build():
    output = ROOT / "dist"
    output.mkdir(exist_ok=True)
    target = output / NAME
    files = sorted(p for p in MOD.rglob("*") if p.is_file())
    if not files:
        raise RuntimeError("No mod files")
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            relative = path.relative_to(MOD).as_posix()
            info = zipfile.ZipInfo(relative, date_time=(2026, 10, 21, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == {p.relative_to(MOD).as_posix() for p in files}
        for path in files:
            assert archive.read(path.relative_to(MOD).as_posix()) == path.read_bytes()
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    (output / "SHA256SUMS.txt").write_text(f"{digest}  {NAME}\n", encoding="utf-8")
    print(f"{target} ({target.stat().st_size} bytes, {len(files)} files)")
    print(f"SHA256 {digest}")
    return target


if __name__ == "__main__":
    build()
