
# CloudBooth

**CloudBooth** is a lightweight macOS menu bar application that automatically syncs your Photo Booth library to iCloud Drive. This ensures that your photos and videos are safely backed up and accessible across all your Apple devices.

## ✨ Features

- **Auto-Sync Modes**: Sync your Photo Booth media automatically:
  - When new photos are added  
  - Every 6 hours, daily, weekly, or monthly  
- **Manual Sync**: Instantly sync with a single click  
- **Sync History Viewer**: See recent sync logs with success/failure status  
- **Destination Options**: Choose between iCloud Drive or a custom folder  
- **Simple Menu Bar Interface**: Sync, view history, and quit from the menu  
- **Built with Swift and SwiftUI**  
- **No configuration needed**—just run and let it sync  

> 🔄 *Auto-sync works in the background. Just keep the app running.*

---

## 🔧 Installation

1. Download the latest version of the app:  
👉 [Releases Page](https://github.com/Navaneeth-Git/CloudBooth/releases)

2. Locate the downloaded file:  
`CloudBooth.app.zip`

3. **Double-click** the `.zip` file to extract `CloudBooth.app`.

4. **(Recommended)** Drag `CloudBooth.app` into your `/Applications` folder.

5. Since the app is **not signed or notarized**, you need to **dequarantine** it:

   Open **Terminal**, type the following command, and **drag the app from Applications into Terminal**:

   ```bash
   xattr -rd com.apple.quarantine 
   ```

   Press `Return`.

6. After this, you can open CloudBooth normally and start syncing.

---

## 🔑 Folder Access Permissions

To function correctly, **CloudBooth will request access multiple times** for the following locations:

- `~/Pictures/Photo Booth Library` (read access)
- Destination folder (iCloud Drive or custom location - write access)

> **You must grant full permission to every folder prompt** for the app to work correctly.

---

## 🔐 Privacy & Security

- **CloudBooth never accesses or uploads your personal files to any third-party services.**
- It **only copies media files** from the local Photo Booth library to your selected destination folder.
- No network activity or data harvesting.  
- All operations are strictly local and private within your Apple ecosystem.

---

## 🧩 How It Works

CloudBooth monitors your Photo Booth Library at:

```bash
~/Pictures/Photo Booth Library
```

It detects new files (based on your sync preference) and copies them to:

- `/Users/[username]/Library/Mobile Documents/com~apple~CloudDocs/CloudBooth` (iCloud), or
- A custom folder you choose.

You can also manually sync anytime using the **Sync Now** button.

---

## 🖼️ Screenshots

<p float="left">
  <img src="https://github.com/user-attachments/assets/fe14f595-43ff-4eca-8304-8db08b5a0c00" width="45%" />
  <img src="https://github.com/user-attachments/assets/0d06cdc2-2c1d-42ed-a219-35daf7b0c34c" width="45%" />
</p>

<p float="left">
  <img src="https://github.com/user-attachments/assets/cf5b0c2b-5b84-4478-a1d2-d922bccb8af2" width="45%" />
  <img src="https://github.com/user-attachments/assets/c6741e38-f8ab-4b92-a221-01b2ecc3c18a" width="45%" />
</p>

---

## 💡 Notes

- CloudBooth runs silently in the background. Check the menu bar for status and controls.
- The sync history tab tracks all your past syncs (success & failure).
- Remember: Auto-sync will only run if the app is kept running in the background.

---

## 🧾 License

This project is licensed under the [Apache License 2.0](LICENSE).

---

## 🙏 Acknowledgments

Created by [Navaneeth-Git](https://github.com/Navaneeth-Git)  
If you found this helpful, please star ⭐ the repo or contribute!

> Synchronize icons by [Tempo_doloe - Flaticon](https://www.flaticon.com/free-icons/synchronize)
