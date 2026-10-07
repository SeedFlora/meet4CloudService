# meet4CloudService - Lab 04 Virtualisasi dan Container

Praktikum COMP6991031. Kasus kerja: tim operasi menjalankan halaman status internal dengan Docker, mendiagnosis layanan yang berhenti, memperbarui pengumuman tanpa rebuild image, dan mengatasi bentrokan port. Semua langkah utama menggunakan Docker CLI dan dapat dicoba pada Docker Desktop di Windows.

**Mulai dari [modul mahasiswa lengkap dengan kunci challenge](MODUL_MAHASISWA.md).** Versi cetak: [PDF modul mahasiswa](output/pdf/MODUL_MAHASISWA_LAB04.pdf). Untuk dosen tersedia [panduan kelas](PANDUAN_DOSEN.md), [PDF panduan dosen](output/pdf/PANDUAN_DOSEN_LAB04.pdf), dan [slide praktikum](slides/LAB04_Docker_Lifecycle_Praktikum.pptx).

## Repo mahasiswa

Buka [SeedFlora/meet4CloudService](https://github.com/SeedFlora/meet4CloudService), klik **Use this template → Create a new repository**, lalu buat salinan di akunmu. Untuk praktik lokal, clone repo milikmu dan buka terminal pada root repo. Di Codespaces, buka repo salinanmu lalu **Code → Codespaces → Create codespace on main** dan ikuti blok Bash pada modul. Hasil akhir dan screenshot praktik pribadi disimpan di repo salinan, bukan di repo template dosen.

## Yang dipelajari

- Membedakan VM, image, dan container; memahami Docker client, daemon, registry, namespaces, dan cgroups.
- Mengunduh dan memeriksa image `nginx:alpine`, `python:3.12-alpine`, dan `node:22-alpine`.
- Memakai `run`, `ps`, `logs`, `exec`, `stop`, `start`, dan `rm` untuk operasi harian.
- Memetakan port host `127.0.0.1:8088` ke port container `80`, memakai environment variable, dan memasang folder `site/` sebagai bind mount read-only.
- Menangani outage, hotfix konten, dan bentrokan port 8088 dengan canary di 8089.

## Mulai cepat - Windows PowerShell

Pastikan Docker Desktop menampilkan **Engine running**. Dari root repo:

```powershell
docker version
docker pull nginx:alpine
docker pull python:3.12-alpine
docker pull node:22-alpine
```

Lanjutkan urutan penuh dalam [modul mahasiswa](MODUL_MAHASISWA.md). Perintah bind mount Windows PowerShell dan Bash/Linux ditulis terpisah agar path dengan spasi tetap aman. Setelah challenge A-E, jalankan `& .\tests\challenge.ps1` di PowerShell atau `bash tests/challenge.sh` di Linux/Codespaces/Git Bash.

## Hasil dan keselamatan data

Isi [templat laporan](hasil/TEMPLATE_LAPORAN.md) dengan output dan screenshot **milik sendiri**. Screenshot dalam modul adalah referensi hasil uji pada komputer dosen. Perintah cleanup hanya untuk container lab bernama `cloudlab-nginx`, `cloudlab-site`, dan `cloudlab-canary`. Jangan commit output penuh `docker info`, token, atau data pribadi. Tidak perlu push image ke registry untuk Lab 04.

Rujukan: [Docker container](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/), [bind mount](https://docs.docker.com/engine/storage/bind-mounts/), [Docker CLI](https://docs.docker.com/reference/cli/docker/).
