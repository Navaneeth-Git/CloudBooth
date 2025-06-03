
# CloudBooth

**CloudBooth** is a lightweight macOS menu bar application that automatically syncs your Photo Booth library to iCloud Drive. This ensures that your photos and videos are safely backed up and accessible across all your Apple devices.

## ✨ Features

- Seamless background syncing of Photo Booth media to iCloud Drive
- Minimalist menu bar interface
- Built with Swift and SwiftUI
- No configuration required—just build and run

## ⚠️ Important Notice

Due to the absence of a paid Apple Developer account, CloudBooth isn't available on the Mac App Store. Additionally, I cannot distribute a pre-built version of the app here on GitHub either. However, you can build and run the app yourself using Xcode with a free Apple ID. This process is straightforward and doesn't require any payment.

## 🛠️ Build & Run Instructions

### Prerequisites

- A Mac running macOS 12.0 (Monterey) or later
- Xcode 13 or later (available for free on the Mac App Store)
- A free Apple ID (no paid developer account needed)

### Steps

1. **Clone the Repository**

   Open Terminal and run:

   ```bash
   git clone https://github.com/Navaneeth-Git/CloudBooth.git
   cd CloudBooth
   ```

2. **Open the Project in Xcode**

   Double-click the `CloudBooth.xcodeproj` file or open it via Xcode:

   ```bash
   open CloudBooth.xcodeproj
   ```

3. **Set Up Signing with Your Apple ID**

   - In Xcode, go to **Xcode > Settings > Accounts**.
   - Click the **+** button and add your Apple ID.
   - Return to the project settings:
     - Select the **CloudBooth** target.
     - Navigate to the **Signing & Capabilities** tab.
     - Under **Team**, select your Apple ID.
     - Ensure **Automatically manage signing** is checked.

   *Note: Xcode will create a free provisioning profile for you.*

4. **Build and Run the App**

   - In the toolbar, select your Mac as the target device.
   - Click the **Run** button (▶️) or press `Cmd + R`.

   The app will build and launch, appearing as an icon in your menu bar.

## 📸 Screenshots

*Please add screenshots of the application here to showcase its interface and functionality.*

To add screenshots:

1. Place your image files (e.g., `screenshot1.png`, `screenshot2.png`) in the repository.
2. Reference them in this README using Markdown syntax:

   ```markdown
   ![Screenshot 1](screenshot1.png)
   ![Screenshot 2](screenshot2.png)
   ```

## 🧩 How It Works

CloudBooth monitors the Photo Booth library located at:

```bash
~/Pictures/Photo Booth Library
```

It automatically copies new photos and videos to a designated folder in your iCloud Drive, ensuring your media is backed up and accessible across your devices.

## 💡 Notes

- The app operates silently in the background; you can access its status via the menu bar icon.
- No additional configuration is required after the initial setup.

## 🧾 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Developed by [Navaneeth-Git](https://github.com/Navaneeth-Git).

If you find this project helpful, consider starring the repository or contributing to its development.
