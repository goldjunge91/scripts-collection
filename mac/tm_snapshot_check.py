import os
from pathlib import Path
from datetime import datetime

# 📁 Pfad zu deinem Time Machine Backup
BACKUP_ROOT = Path("/Volumes/.timemachine/6D082BF7-1AA7-41CD-A75A-4A16F67F923F/Backups.backupdb")

def get_size_and_count(path: Path):
    total_size = 0
    file_count = 0
    for root, dirs, files in os.walk(path):
        for f in files:
            try:
                fp = Path(root) / f
                total_size += fp.stat().st_size
                file_count += 1
            except Exception:
                pass  # Zugriffsfehler ignorieren
    return total_size, file_count

def human_readable(size_bytes):
    gb = size_bytes / (1024 ** 3)
    return f"{gb:.2f} GB"

def analyze_snapshots():
    print(f"\n📦 Analyse von Time Machine Snapshots unter:\n{BACKUP_ROOT}\n")

    if not BACKUP_ROOT.exists():
        print("❌ Backup-Verzeichnis nicht gefunden!")
        return

    snapshots = sorted([p for p in BACKUP_ROOT.glob("*") if p.is_dir()])
    if not snapshots:
        print("⚠️ Keine Snapshots gefunden.")
        return

    for snapshot in snapshots:
        print(f"🔹 Snapshot: {snapshot.name}")
        # Macintosh HD - Data (kann je nach macOS-Version auch anders heißen)
        data_path = snapshot / "Macintosh HD - Data"
        if not data_path.exists():
            # Fallback: direkt in snapshot nachsehen
            data_path = snapshot

        size, count = get_size_and_count(data_path)
        print(f"    📁 Dateien: {count:,}")
        print(f"    💾 Größe  : {human_readable(size)}\n")

if __name__ == "__main__":
    analyze_snapshots()
