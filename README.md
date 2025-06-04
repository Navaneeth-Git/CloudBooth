# CloudBooth

**CloudBooth** is a lightweight macOS menu bar application that automatically syncs your Photo Booth library to iCloud Drive. This ensures that your photos and videos are safely backed up and accessible across all your Apple devices.

## ✨ Features

- Seamless background syncing of Photo Booth media to iCloud Drive  
- Minimalist menu bar interface  
- Built with Swift and SwiftUI  
- No configuration required—just run and let it sync  

## 🔐 Privacy & Security

- **CloudBooth never accesses or uploads your personal files to any third-party cloud services.**  
- The app *only* copies media files from the local Photo Booth library to your iCloud Drive directory—*nothing more*.  
- No internet communication or data harvesting of any kind is performed. Your media remains private and local to your Apple ecosystem.

## 🔑 Folder Access Permission

To function correctly, **CloudBooth requires permission to access the following directories**:

- `~/Pictures/Photo Booth Library`
- Your desired iCloud Drive destination

Upon first run, macOS will prompt you to grant access to these folders. Please ensure you approve access for the app to sync your media.

## ⚠️ Important Notice

Since I don’t have an Apple Developer account, I’m unable to sign or notarize the app. Instead, I’ve pulled out the unsigned **debug build** from Xcode for you to use. Because of this, macOS may block the app when you try to open it.

### 🧭 How to Open the Unsigned App

After downloading and unzipping the app from the release:

1. Move the app to your `/Applications` folder (optional but recommended).
2. Right-click the app and select **Open**.
3. A warning dialog will appear – click **Open** again.
4. From then on, you can launch it like any other app.

> You only need to do this once. macOS will remember your choice.

## 📦 Download

You can find the latest debug build here:  
👉 [Releases Page](https://github.com/Navaneeth-Git/CloudBooth/releases)

## 📸 Screenshots

![64](https://github.com/user-attachments/assets/5b7fd386-7b23-4468-8f10-1015919bb4f7)

<p float="left">
  <img src="https://github.com/user-attachments/assets/fe14f595-43ff-4eca-8304-8db08b5a0c00" width="45%" />
  <img src="https://github.com/user-attachments/assets/0d06cdc2-2c1d-42ed-a219-35daf7b0c34c" width="45%" />
</p>

<p float="left">
  <img src="https://github.com/user-attachments/assets/cf5b0c2b-5b84-4478-a1d2-d922bccb8af2" width="45%" />
  <img src="https://github.com/user-attachments/assets/c6741e38-f8ab-4b92-a221-01b2ecc3c18a" width="45%" />
</p>

## 🧩 How It Works

CloudBooth monitors the Photo Booth library located at:

```bash
~/Pictures/Photo Booth Library
```

It automatically copies any new media files (photos/videos) to a designated folder in your **iCloud Drive**, ensuring they are backed up and available on your other devices.

## 💡 Notes

- CloudBooth runs silently in the background. You can view the sync status and other options by clicking the menu bar icon.  
- No additional setup is required after initial permissions are granted.  

## 🧾 License

This project is licensed under the [Apache License 2.0](LICENSE).

## 🙏 Acknowledgments

Pulled together without code signing by [Navaneeth-Git](https://github.com/Navaneeth-Git).  
If you find this project helpful, consider starring the repository or contributing!  
<a href="https://www.flaticon.com/free-icons/synchronize" title="synchronize icons">Synchronize icons created by Tempo_doloe - Flaticon</a>
"""
