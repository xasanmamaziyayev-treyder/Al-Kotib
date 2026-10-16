# AI Kotib & Smart Diktofon (Xasan Zokirovich uchun)

Ushbu loyiha yig'ilishlarni diktofonda yozib olib, Gemini 2.5 Flash AI yordamida sizga tegishli topshiriqlarni va muddatlarni (Deadline) avtomatik saralab beruvchi Android ilova hisoblanadi.

## Qanday qilib 5 daqiqada tayyor `.apk` fayl olinadi?

1. **GitHub**'da yangi repository oching (masalan: `ai-kotib-apk`).
2. Ushbu arxiv ichidagi barcha fayllarni (`pubspec.yaml`, `lib/main.dart`, `.github/workflows/build.yml`) o'sha repositoryga yuklang (Commit & Push).
3. GitHub sahifangizning yuqorisidagi **Actions** bo'limiga o'ting.
4. U yerda **"Build AI Kotib APK"** jarayoni avtomatik ishga tushadi va ~3-4 daqiqada yashil (✅) bo'lib yakunlanadi.
5. Jarayon ustiga bosib, pastdagi **Artifacts** qismidan **`AI-Kotib-Xasan-APK`** faylini yuklab oling — uning ichida tayyor **`app-release.apk`** bo'ladi!
