# Laporan Lab 04 - Virtualisasi dan Container

Nama: [isi]
Kelas: [isi]
Tanggal: [isi]
Repo hasil: [isi]

## 1. Image dan container

Tuliskan perbedaan VM, image, dan container dalam kalimat sendiri. Catat image nginx, Python, dan Node yang dipakai. Sertakan bukti `docker image ls`.

## 2. Pemetaan port dan bind mount

Jelaskan arti `127.0.0.1:8088:80` serta `source=.../site,target=/usr/share/nginx/html,readonly`. Sertakan screenshot halaman awal, `docker ps`, dan hasil inspect mount (`RW=false`).

## 3. Insiden layanan

Tuliskan gejala HTTP saat `cloudlab-site` berhenti, perintah diagnosis, langkah pemulihan, dan hasil HTTP sesudah `start`. Sertakan bukti sebelum/sesudah.

## 4. Hotfix dan bentrokan port

Catat perubahan teks `INCIDENT-042: Pemeliharaan selesai`, image ID sebelum/sesudah, error saat 8088 dipakai dua container, dan solusi canary 8089. Sertakan screenshot halaman akhir, output port, dan hasil challenge A-E.

## 5. Refleksi kerja harian

Jika layanan produksi mati, urutkan pemeriksaan pertama yang akan dilakukan dan jelaskan kapan memakai `start` dibanding membuat container baru. Jelaskan mengapa bind mount read-only mengurangi risiko.

## Bukti

Simpan screenshot sendiri dalam `hasil/bukti/lab04/` dan tautkan di sini. Hindari data pribadi atau output `docker info` penuh.
