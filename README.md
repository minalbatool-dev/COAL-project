# 🦖 Dino Game (x86 Assembly Language)

A fully functional, console-based clone of the classic Chrome Dino Game, built entirely in **x86 Assembly Language** for my **Computer Organization & Assembly Language (COAL)** course.

## 📖 Overview
This project demonstrates low-level hardware control, direct video memory manipulation, and interrupt handling. The game features animated backgrounds, random obstacle generation, collision detection, and interactive UI screens.

## ✨ Features

- **Static & Animated Graphics:** Custom rendering of the Dino, moving road, and parallax-scrolling clouds directly to video memory.
- **Randomized Obstacles:** Cacti spawn randomly to challenge the player.
- **Collision Detection:** Accurate hitboxes to detect when the Dino crashes.
- **Score Tracking:** Real-time score display on the top right of the screen.
- **Interrupt-Driven Input:**
  - **Keyboard Interrupt (Int 9):** Handles the Dino's jump mechanics and the ESC key.
  - **Software Interrupts:** Handles text input (like 'Y' for Yes), menu rendering, and system exits.
- **Timer Interrupt:** Used to drive the animation and game loop (road movement, clouds, and obstacle shifting).
- **Game States:**
  - *Intro Screen:* Displays game title, student roll numbers, names, and semester.
  - *Pause/Exit Screen:* Pressing ESC prompts a confirmation to quit.
  - *Game Over Screen:* Displays the final score upon collision.

## 🛠️ Technical Highlights (What's under the hood)

- **Direct Video Memory (0xB800):** Instead of relying on slow print functions, the game writes characters and colors directly to video memory for smooth, flicker-free animation.
- **Interrupt Vector Table (IVT) Overriding:** Custom Interrupt Service Routines (ISRs) are hooked to handle hardware inputs and timer ticks.
- **Parallax Effect:** Background clouds and foreground roads move at different frequencies to create depth.

## 🚀 How to Run

### Prerequisites
To run this game, you need an x86 DOS emulator.
- **DOSBox** (Recommended)
- **NASM** or **MASM** (if you want to compile it yourself)
- **AFD** (Advanced Fullscreen Debugger) or standard DOS DEBUG (for debugging)

### Steps to Play
1. Clone this repository or download the `.asm` file.
2. Open **DOSBox**.
3. Mount your directory: `mount c C:\path\to\your\folder`
4. Switch to the drive: `c:`
5. Compile and link

