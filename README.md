# Quickshell App Launchers

A collection of highly customizable, visually distinct app launchers built for **Quickshell** using QML and JavaScript. This repository contains 8 unique launcher themes, ranging from sci-fi HUDs to cozy simulators, all powered by a common application database.

## 📂 Directory Contents

This project includes the following launcher themes:

| File Name | Theme / Style | Description |
| :--- | :--- | :--- |
| `3d tree.qml` | **3D Forge** | A 3D orbital galaxy of apps. Drag to tumble the 360° trackball, spin with the wheel, and detonate apps with lightning bolt lock-ons. |
| `card.qml` | **Aurora Coverflow** | A sleek, frosted-glass coverflow deck floating over an animated, colorful aurora background. |
| `game.qml` | **Pixel Arcade** | An 80s arcade cabinet aesthetic with CRT scanlines, "INSERT COIN" blinking text, and pixelated app cartridges. |
| `iron man.qml` | **Stark OS** | A Jarvis-style HUD with an animated arc reactor, rotating data rings, holo-chips, and a sci-fi boot sequence. |
| `kill room.qml` | **The Red Room** | A dark, horror-themed "kill list". Features blood drips, a killer crosshair cursor, heartbeats, and floating whispers. |
| `lazy.qml` | **Lo-Fi Studio** | A cozy bedroom scene with rain on the window, a cat, a steaming mug, and a working vinyl turntable that spins your selected app. |
| `simple.qml` | **Minimal Board** | A clean, Tokyo Night-inspired grid dashboard with a clock, an equalizer widget, and responsive app tiles. |
| `ta da !!.qml` | **Candy Pop** | A bright, playful party theme with color bubbles, confetti, floating balloons, and a cute mascot cat. |
| `the 80s.qml` | **Outrun / Synthwave** | An 80s retro-future scene with a neon sun, perspective grid, and chrome text. |

## 🛠️ Prerequisites

Before running these launchers, ensure you have the following installed on your system:

* **Quickshell** (A desktop shell toolkit for Wayland/X11)
* **Bash** (for the utility scripts)
* **A Terminal Emulator** (Defaults to `alacritty`, changeable in the source code)

## 🚀 Installation & Setup

1. **Clone or download** this repository to your local config directory (e.g., `~/.config/quickshell/tree/`).
2. **Make the scripts executable:**

    ```bash
    chmod +x launch-tree.sh list-apps.sh
    ```

3. **Run the launcher:**

    ```bash
    ./launch-tree.sh
    ```





----



<img width="1920" height="1077" alt="Image" src="https://github.com/user-attachments/assets/11a22b31-d339-49a0-bf42-051735245340" />

<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/b8d154fa-c8f3-4ae9-8fb2-f061e7d387aa" />

<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/98b3a786-11c3-4ccf-a6c3-b708318fd81b" />

<img width="1913" height="1074" alt="Image" src="https://github.com/user-attachments/assets/6cf272b1-df87-422e-a41c-205060c481d1" />

<img width="1917" height="1080" alt="Image" src="https://github.com/user-attachments/assets/161d393a-241e-4167-8728-c7368be7a8b7" />

<img width="1920" height="1078" alt="Image" src="https://github.com/user-attachments/assets/11c9d3f9-9eee-4420-b316-109c3527d769" />

<img width="1920" height="1077" alt="Image" src="https://github.com/user-attachments/assets/22102261-48f6-451e-8516-46ab292ebed2" />

<img width="1917" height="1080" alt="Image" src="https://github.com/user-attachments/assets/170a6da6-57f5-4668-8d10-34d03fe28c39" />

<img width="1920" height="1079" alt="Image" src="https://github.com/user-attachments/assets/7b9fa47e-7892-401f-93a0-de87e6fbe6d0" />



----





## ⚙️ How It Works

### The App Database (`apps.js`)

The launchers dynamically read from `apps.js`, which is a generated JavaScript file containing a list of your installed applications. The script scans standard Linux `.desktop` file directories to extract app names, categories, icons, and launch commands.

### Utility Scripts

* `launch-tree.sh`: Checks if the `apps.js` cache is over 30 minutes old. If so, it triggers a rescan by calling `list-apps.sh`, and then launches Quickshell.
* `list-apps.sh`: A Bash script that scans your system for `.desktop` files (including Flatpak and `.local` directories), resolves their icons, and regenerates the `apps.js` file.

## 🖱️ General Controls

While each launcher has its own unique aesthetic, they share common navigation methods:

* **Search:** Type in the search box to filter apps.
* **Navigate:**
  * *Wheel / Arrows:* Cycle through apps or cards.
  * *Mouse Hover:* Select an app in many of the launchers.
* **Launch:** Press `Enter` or click on the selected app.
* **Close / Quit:** Press `Esc` (or click empty space in some themes).

> **Note:** Many launchers have specific controls (e.g., dragging the trackball in `3d tree.qml` or dragging the deck in `card.qml`). Look at the bottom of the screen in each launcher for an on-screen guide.

## 🎨 Customization

To change the default terminal emulator used by console apps (like `htop` or `btop`), look for the following property in the `.qml` file and change it to your preferred terminal:

```qml
property string term: "alacritty"
```

You can also edit the color palettes found at the top of each `.qml` file (e.g., `readonly property color cGold: "#fbbf24"`) to match your personal setup.
