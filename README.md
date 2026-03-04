# Catpaq

## GUI explorer for ZPAQ archives powered by zpaqfranz. Browse versions, extract files, test integrity and add new content — no installation required.

![catpaq screenshot](screenshots/main.png)

ZPAQ is one of the best compression formats around — great compression ratio, incremental backups, full version history. The catch: it has no official GUI. **catpaq** fixes that. Drop it next to `zpaqfranz`, open an archive, and you're done.

---

## Features

-  **Browse any ZPAQ archive** — see all files and folders, with full version history
-  **Time machine** — navigate between archive snapshots and extract any past version of a file
-  **Integrity test** — verify your archive with real-time progress and ETA, results shown directly in the log
-  **Add files** — select files and folders from the built-in file explorer and add them to any archive
-  **Extract** — extract single files, folders, or everything, with GUI destination picker
-  **Encrypted archives** — supports AES and Franzen password protection
-  **Filter & search** — quickly find files inside large archives
-  **Hash calculation** — CRC32, SHA256, BLAKE3, XXH3 and many more, with clipboard copy on single file
-  **Portable** — no installer, no registry, no admin rights needed (unless you want file associations)
-  **Cross-platform** — runs on Windows, Linux and macOS (_work in progress_)

---

## Requirements

Catpaq is a front-end: it needs the `zpaqfranz` executable to do the actual work, and will offer to download it for you (on Windows).
BTW `zpaqfranz` [official repository](https://github.com/fcorbelli/zpaqfranz)

---

## Installation

No installer required.

1. Download the latest release from the [Releases page](../../releases)
2. Unzip the archive to any folder you like
3. Place `zpaqfranz` (or `zpaqfranz.exe` on Windows) in the same folder
4. Run `catpaq.exe` (Windows) or `catpaq` (Linux/macOS)

(Windows) To open `.zpaq` files directly from your file manager, run catpaq as Administrator and use **Settings → Associate .zpaq and .zpaq.franzen**.

---

## Screenshots

| Archive browser | Integrity test | File explorer |
|---|---|---|
| ![Browse](screenshots/browse.png) | ![Test](screenshots/test.png) | ![Explorer](screenshots/explorer.png) |

---

## How it works

Catpaq is a GUI layer over `zpaqfranz`. 
Every action — listing, extracting, testing, adding — translates into a `zpaqfranz` command that runs in the background. 
Output is streamed live into the Log tab, so you always see exactly what's happening.

The **Add tab** is a built-in file explorer: navigate your drives, select files, and send them to any archive in a few clicks. 
No drag-and-drop from an external window needed.

---

## Building from source

Catpaq is written in **Free Pascal / Lazarus**. To build it yourself:

1. Install [Lazarus](https://www.lazarus-ide.org/) (tested with 4.x)
2. Clone this repository
3. Open `catpaq.lpr` in the Lazarus IDE
4. Build → Compile

Almost no external dependency 

---

## Credits

Catpaq is a front-end for [zpaqfranz](https://github.com/fcorbelli/zpaqfranz) by Franco Corbelli, which is itself based on [ZPAQ](http://mattmahoney.net/dc/zpaq.html) by Matt Mahoney. All the heavy lifting — compression, encryption, verification — is done by zpaqfranz.

---

## License

MIT — see [LICENSE](LICENSE) for details.
