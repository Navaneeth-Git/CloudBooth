
# CloudBooth

**CloudBooth** is a lightweight macOS menu bar application that automatically syncs your Photo Booth library to iCloud Drive. This ensures that your photos and videos are safely backed up and accessible across all your Apple devices.

## ✨ Features

- Seamless background syncing of Photo Booth media to iCloud Drive  
- Minimalist menu bar interface  
- Built with Swift and SwiftUI  
- No configuration required—just build and run  

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

Due to the absence of a paid Apple Developer account, CloudBooth isn't available on the Mac App Store. Additionally, I cannot distribute a pre-built version of the app here on GitHub either. However, you can build and run the app yourself using Xcode with a free Apple ID. This process is straightforward and doesn't require any payment.

## 🛠️ Build & Run Instructions

### Prerequisites

- A Mac running macOS 12.0 (Monterey) or later  
- Xcode 13 or later (available for free on the Mac App Store)  
- A free Apple ID (no paid developer account needed)  

### Steps

1. **Clone the Repository**

   ```bash
   git clone https://github.com/Navaneeth-Git/CloudBooth.git
   cd CloudBooth
   ```

2. **Open the Project in Xcode**

   ```bash
   open CloudBooth.xcodeproj
   ```

3. **Set Up Signing with Your Apple ID**

   - In Xcode, go to **Xcode > Settings > Accounts**  
   - Click the **+** button and add your Apple ID  
   - Go back to the project settings:  
     - Select the **CloudBooth** target  
     - Navigate to **Signing & Capabilities**  
     - Under **Team**, select your Apple ID  
     - Make sure **Automatically manage signing** is enabled  

4. **Build and Run the App**

   - Select your Mac as the target device  
   - Click the **Run** button (▶️) or press `Cmd + R`  
   - CloudBooth will launch and appear in your menu bar  

## 📦 Executable Download

If you're looking for a pre-built version (Swift executable) of **CloudBooth**, you can find it in this repository:

👉 [CloudBooth Executable Repository](https://github.com/Navaneeth-Git/CloudBooth/releases)

## 📸 Screenshots

<p float="left">
  <img src="https://github.com/user-attachments/assets/fe14f595-43ff-4eca-8304-8db08b5a0c00" width="45%" />
  <img src="https://github.com/user-attachments/assets/0d06cdc2-2c1d-42ed-a219-35daf7b0c34c" width="45%" />
</p>

![Screenshot 2025-06-04 at 3 17 22 AM](https://github.com/user-attachments/assets/cf5b0c2b-5b84-4478-a1d2-d922bccb8af2)
![Screenshot 2025-06-04 at 3 17 49 AM](https://github.com/user-attachments/assets/c6741e38-f8ab-4b92-a221-01b2ecc3c18a)


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

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Developed by [Navaneeth-Git](https://github.com/Navaneeth-Git).  
If you find this project helpful, consider starring the repository or contributing!
