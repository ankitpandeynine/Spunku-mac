# 🔊 Spunku for macOS

Welcome to **Spunku**! This is a lightweight, advanced macOS utility designed to bring dynamic system audio experiences to your Mac, featuring real-time keyboard typing sounds, smooth polyphonic audio playback, and intelligent power management.

---

## ✨ Features

* **🎵 Polyphonic Audio Engine:** Built with multi-voice support (`voices`), allowing multiple sound effects to overlap smoothly without cutting each other off or stuttering.
* **⌨️ Keyboard Typing Feedback:** Instantaneous real-time monitoring and sound feedback as you type on your keyboard.
* **🔋 IOKit Power & Lid Intelligence:** Automatically tracks system power states and lid open/close events to handle background audio behaviors seamlessly and efficiently.
* **🪶 Low Resource Footprint:** Optimized natively in Swift for macOS, running quietly in the background without draining your battery or system resources.

----

## Screenshots

### Actual Layout

<p align="center">
  <img src="https://github.com/user-attachments/assets/2acee602-0cf4-41bb-81d6-cbbd829d40aa" width="365" alt="Actual Layout">
</p>

### Overall Look on Mac

<p align="center">
  <img src="https://github.com/user-attachments/assets/f1a3b9cd-5fd6-4ae7-84d4-b350d7fed144" width="900" alt="Overall Look on Mac">
</p>

### First-Time Password Access

<p align="center">
  <img src="https://github.com/user-attachments/assets/b20d457c-baad-49b9-a648-19f6c5357d64" width="900" alt="First-Time Password Access">
</p>

---

## 📥 Installation Guide (For End Users)

If you downloaded Spunku from the releases page, follow these quick steps to get started:

1. **Download the App**
   Head over to the **[Releases Page](https://github.com/ankitpandeynine/Spunku-mac/releases)** and download the latest **`Spunku.zip`** file.
2. **Extract the Archive**
   Double-click the downloaded `.zip` file in your Downloads folder to extract **`Spunku.app`**.
3. **Move to Applications**
   Drag and drop **`Spunku.app`** directly into your **Applications** folder for easy access.
4. **Launch & Authorize**
   Open the app (see the security section below for the initial macOS bypass if required).

---

## 🛠️ Developer Setup & Build Guide

If you prefer to clone the repository and build the source code yourself using Xcode:

1. **Clone the Repository**
   Open your Terminal and clone the project:
   ```bash
   git clone [https://github.com/ankitpandeynine/Spunku-mac.git](https://github.com/ankitpandeynine/Spunku-mac.git)
   cd Spunku-mac
   ```
2. **Open in Xcode**
   Open the project folder and launch Xcode, or open it directly via terminal:
   ```bash
   open .
   ```
3. **Build and Run**
   Select your target scheme, choose your Mac as the destination, and press **`Cmd + R`** to run the project.

---

## 🛡️ Bypassing macOS Security ("Open Anyway")

Because Spunku is independently distributed and not currently signed with a paid Apple Developer certificate, macOS Gatekeeper will block it the very first time you try to open it with a warning stating that *“Apple cannot check it for malicious software.”*

To safely bypass this and run your app:

1. Try opening **Spunku** from your Applications folder. A warning box will appear; click **OK** to dismiss it.
2. Open **System Settings** on your Mac.
3. Click on **Privacy & Security** in the left-hand sidebar.
4. Scroll down until you see the security message stating: *"Spunku was blocked from use because it is not from an identified developer."*
5. Click the **Open Anyway** button next to it.
6. Enter your Mac login password or use Touch ID to authorize the change.
7. A final confirmation pop-up will appear. Click **Open**.

The app will now launch successfully, and macOS will remember your exception for all future updates!

---

## 📂 Core Architecture

* `SystemSoundEngine.swift`: The core audio engine handling polyphony, multi-voice mixing, keyboard event listeners, and IOKit power/lid state integrations.
* **Native Swift Modules:** Clean, modular components managing application lifecycle, event coordination, and native system hooks.

---

## 🙏 Acknowledgements & Credits

A massive thank you to **[taigrr](https://github.com/taigrr)** for creating **[spank](https://github.com/taigrr/spank)**. 

* **Backend Architecture & Logic:** The underlying system architecture and execution flows were designed using concepts from his project.
* **Hardware Integration:** The low-level IOKit sensor monitoring, power state tracking, and event-handling techniques were adapted directly from `spank` to deliver seamless audio and keyboard feedback on macOS.

Please make sure to check out, star, and support his original project at **[github.com/taigrr/spank](https://github.com/taigrr/spank)**!

---

## ⚠️ Disclaimer

This application is built for personal use and enhancement of the macOS audio experience. The creator is not responsible for any unexpected system behavior or configuration modifications resulting from third-party utility usage.

---

**Made with ❤️ by [ankitpandeynine](https://github.com/ankitpandeynine)**
